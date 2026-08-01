package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"syscall"
)

var version = "dev"

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := run(ctx, os.Args[1:], os.Stdin, os.Stdout, os.Stderr); err != nil {
		if errors.Is(err, context.Canceled) {
			return
		}
		fmt.Fprintln(os.Stderr, "mac-cleaner:", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, args []string, in io.Reader, out, errOut io.Writer) error {
	if runtime.GOOS != "darwin" {
		return errors.New("this tool only supports macOS")
	}
	rootful, args := extractRootFlag(args)
	if err := validateRootMode(rootful, os.Geteuid()); err != nil {
		return err
	}
	home, identity, err := scanIdentity(rootful)
	if err != nil {
		return err
	}

	if len(args) == 0 {
		if !isTerminal(os.Stdin) || !isTerminal(os.Stdout) {
			printUsage(out)
			return nil
		}
		return runTUI(ctx, home, rootful, identity, out)
	}

	switch args[0] {
	case "scan":
		return runScanCommand(ctx, home, rootful, identity, args[1:], out, errOut)
	case "plan":
		return runPlanCommand(ctx, home, rootful, identity, args[1:], out, errOut)
	case "clean":
		return runCleanCommand(ctx, home, rootful, identity, args[1:], in, out, errOut)
	case "version", "--version", "-version":
		fmt.Fprintln(out, version)
		return nil
	case "help", "--help", "-h":
		printUsage(out)
		return nil
	default:
		return fmt.Errorf("unknown command %q, try mac-cleaner help", args[0])
	}
}

func runScanCommand(ctx context.Context, home string, rootful bool, identity *commandIdentity, args []string, out, errOut io.Writer) error {
	flags := flag.NewFlagSet("scan", flag.ContinueOnError)
	flags.SetOutput(errOut)
	deep := flags.Bool("deep", false, "scan project build state")
	jsonOutput := flags.Bool("json", false, "print machine-readable json")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 0 {
		return errors.New("scan does not take item ids")
	}
	report := configuredScanner(home, *deep, rootful, identity).Scan(ctx)
	if *jsonOutput {
		encoder := json.NewEncoder(out)
		encoder.SetIndent("", "  ")
		return encoder.Encode(report)
	}
	printReport(out, report)
	return nil
}

func runPlanCommand(ctx context.Context, home string, rootful bool, identity *commandIdentity, args []string, out, errOut io.Writer) error {
	flags := flag.NewFlagSet("plan", flag.ContinueOnError)
	flags.SetOutput(errOut)
	deep := flags.Bool("deep", false, "scan project build state")
	allSafe := flags.Bool("all-safe", false, "select every safe action")
	if err := flags.Parse(args); err != nil {
		return err
	}
	report := configuredScanner(home, *deep, rootful, identity).Scan(ctx)
	items, err := resolveItems(report, flags.Args(), *allSafe)
	if err != nil {
		return err
	}
	fmt.Fprint(out, planText(items))
	return nil
}

func runCleanCommand(ctx context.Context, home string, rootful bool, identity *commandIdentity, args []string, in io.Reader, out, errOut io.Writer) error {
	flags := flag.NewFlagSet("clean", flag.ContinueOnError)
	flags.SetOutput(errOut)
	deep := flags.Bool("deep", false, "scan project build state")
	allSafe := flags.Bool("all-safe", false, "select every safe action")
	dryRun := flags.Bool("dry-run", false, "show actions without changing anything")
	yes := flags.Bool("yes", false, "skip the normal confirmation")
	confirm := flags.String("confirm", "", "required phrase for irreversible automation")
	if err := flags.Parse(args); err != nil {
		return err
	}
	report := configuredScanner(home, *deep, rootful, identity).Scan(ctx)
	items, err := resolveItems(report, flags.Args(), *allSafe)
	if err != nil {
		return err
	}
	fmt.Fprint(out, planText(items))
	if *dryRun {
		results := executeItems(ctx, home, items, true, out)
		return actionErrors(results)
	}

	phrase := confirmationPhrase(items)
	if *yes {
		if phrase == "empty trash" && *confirm != phrase {
			return errors.New("irreversible cleanup needs --confirm 'empty trash'")
		}
	} else {
		fmt.Fprintf(out, "\ntype %q to continue: ", phrase)
		answer, readErr := bufio.NewReader(in).ReadString('\n')
		if readErr != nil && !errors.Is(readErr, io.EOF) {
			return readErr
		}
		if strings.TrimSpace(answer) != phrase {
			return errors.New("confirmation did not match, no changes made")
		}
	}

	results := executeItems(ctx, home, items, false, out)
	return actionErrors(results)
}

func extractRootFlag(args []string) (bool, []string) {
	rootful := false
	filtered := make([]string, 0, len(args))
	for _, arg := range args {
		if arg == "--root" {
			rootful = true
			continue
		}
		filtered = append(filtered, arg)
	}
	return rootful, filtered
}

func validateRootMode(rootful bool, effectiveUID int) error {
	if rootful && effectiveUID != 0 {
		return errors.New("--root requires uid 0: sudo mac-cleaner --root")
	}
	return nil
}

func scanIdentity(rootful bool) (string, *commandIdentity, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", nil, err
	}
	if !rootful {
		return home, nil, nil
	}
	username := os.Getenv("SUDO_USER")
	uid, uidErr := strconv.ParseUint(os.Getenv("SUDO_UID"), 10, 32)
	gid, gidErr := strconv.ParseUint(os.Getenv("SUDO_GID"), 10, 32)
	if username == "" || username == "root" || uidErr != nil || gidErr != nil || !validUsername(username) {
		return home, nil, nil
	}
	candidate := filepath.Join("/Users", username)
	if info, statErr := os.Stat(candidate); statErr == nil && info.IsDir() {
		home = candidate
	}
	return home, &commandIdentity{
		UID:      uint32(uid),
		GID:      uint32(gid),
		Groups:   userGroups(username, uint32(gid)),
		Username: username,
		Home:     home,
	}, nil
}

func userGroups(username string, primary uint32) []uint32 {
	output, err := exec.Command("/usr/bin/id", "-G", username).Output()
	if err != nil {
		return []uint32{primary}
	}
	groups := make([]uint32, 0, len(strings.Fields(string(output))))
	seen := make(map[uint32]bool)
	for _, field := range strings.Fields(string(output)) {
		value, parseErr := strconv.ParseUint(field, 10, 32)
		if parseErr != nil || seen[uint32(value)] {
			continue
		}
		group := uint32(value)
		seen[group] = true
		groups = append(groups, group)
	}
	if len(groups) == 0 {
		return []uint32{primary}
	}
	return groups
}

func validUsername(username string) bool {
	return username != "" && username != "." && username != ".." && filepath.Base(username) == username
}

func configuredScanner(home string, deep, rootful bool, identity *commandIdentity) Scanner {
	scanner := NewScanner(home, deep)
	scanner.Rootful = rootful
	scanner.CommandIdentity = identity
	return scanner
}

func resolveItems(report Report, args []string, allSafe bool) ([]Item, error) {
	ids := make(map[string]bool)
	if allSafe {
		for _, item := range report.Items {
			if item.Risk == RiskSafe && item.Selectable() {
				ids[item.ID] = true
			}
		}
	}
	for _, value := range args {
		for _, id := range strings.Split(value, ",") {
			id = strings.TrimSpace(id)
			if id != "" {
				ids[id] = true
			}
		}
	}
	if len(ids) == 0 {
		return nil, errors.New("choose at least one item id or use --all-safe")
	}
	for id := range ids {
		item, ok := itemByID(report, id)
		if !ok {
			return nil, fmt.Errorf("unknown item id %q", id)
		}
		if !item.Selectable() {
			return nil, fmt.Errorf("item %q is not cleanable", id)
		}
	}
	items := selectedItems(report, ids)
	sort.SliceStable(items, func(a, b int) bool {
		return riskOrder(items[a].Risk) < riskOrder(items[b].Risk)
	})
	return items, nil
}

func confirmationPhrase(items []Item) string {
	for _, item := range items {
		if item.Action != nil && item.Action.Kind == ActionEmptyTrash {
			return "empty trash"
		}
	}
	return "clean"
}

func actionErrors(results []ActionResult) error {
	var failed []string
	for _, result := range results {
		if result.Error != nil {
			failed = append(failed, result.Name)
		}
	}
	if len(failed) > 0 {
		return fmt.Errorf("%d action(s) failed: %s", len(failed), strings.Join(failed, ", "))
	}
	return nil
}

func printReport(out io.Writer, report Report) {
	if report.Disk.Total > 0 {
		percent := float64(report.Disk.Free) / float64(report.Disk.Total) * 100
		fmt.Fprintf(out, "%s free of %s on %s (%.1f%%)\n\n", humanBytes(report.Disk.Free), humanBytes(report.Disk.Total), report.Disk.Path, percent)
	}
	scope := "user"
	if report.Rootful {
		scope = "root"
	}
	fmt.Fprintf(out, "scope %s\n\n", scope)
	fmt.Fprintf(out, "%-25s %-21s %-11s %10s  %s\n", "id", "category", "risk", "size", "item")
	for _, item := range report.Items {
		fmt.Fprintf(out, "%-25s %-21s %-11s %10s  %s\n", item.ID, displayCategory(item.Category), item.Risk, humanBytes(item.Bytes), item.Name)
		if item.Unavailable != "" {
			fmt.Fprintf(out, "  unavailable: %s\n", item.Unavailable)
		}
	}
	if len(report.Issues) > 0 {
		fmt.Fprintf(out, "\nnotes=%d\n", len(report.Issues))
	}
}

func printUsage(out io.Writer) {
	fmt.Fprint(out, `mac-cleaner

usage:
  mac-cleaner [--root]
  mac-cleaner scan [--root] [--deep] [--json]
  mac-cleaner plan [--root] [--deep] [--all-safe] <item-id>...
  mac-cleaner clean [--root] [--deep] [--all-safe] [--dry-run] <item-id>...

--root requires uid 0 and adds System Data, macOS and Other Users inventory
`)
}

func isTerminal(file *os.File) bool {
	info, err := file.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}
