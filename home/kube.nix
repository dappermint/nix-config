{ config, ... }:

{
  # merge the conway k8s cluster (sops-managed at ~/.kube/conway) with existing contexts
  home.sessionVariables.KUBECONFIG = "${config.home.homeDirectory}/.kube/config:${config.home.homeDirectory}/.kube/conway";
}
