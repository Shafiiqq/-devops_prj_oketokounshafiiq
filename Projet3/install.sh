#!/usr/bin/env bash

APP_NAME="k3d"
REPO_URL="https://github.com/rancher/k3d"

: ${USE_SUDO:="true"}
: ${K3D_INSTALL_DIR:="/usr/local/bin"}

# initArch découvre l'architecture de ce système.
initArch() {
  ARCH=$(uname -m)
  cas $ARCH dans
    armv5*) ARCH="armv5";;
    armv6*) ARCH="armv6";;
    armv7*) ARCH="arm";;
    aarch64) ARCH="arm64";;
    x86) ARCH="386";;
    x86_64) ARCH="amd64";;
    i686) ARCH="386";;
    i386) ARCH="386";;
  esac
}

# initOS découvre le système d'exploitation pour ce système.
initOS() {
  OS=$(uname|tr '[:upper:]' '[:lower:]')

  cas "$OS" dans
    # GNU minimaliste pour Windows
    mingw*) OS='windows';;
  esac
}

# exécute la commande donnée en tant que root (détecte si nous sommes déjà root)
exécuterAsRoot() {
  local CMD="$*"

  if [ $EUID -ne 0 -a $USE_SUDO = "true" ]; alors
    CMD="sudo $CMD"
  Fi

  $CMD
}

# verifySupported vérifie que la combinaison os/arch est prise en charge pour
# compilations binaires.
vérifierSupporté() {
  local pris en charge="darwin-386\ndarwin-amd64\ndarwin-arm64\nlinux-386\nlinux-amd64\nlinux-arm\nlinux-arm64\nwindows-386\nwindows-amd64"
  si ! echo "${supporté}" | grep -q "${OS}-${ARCH}" ; alors
    echo "Aucun binaire prédéfini pour ${OS}-${ARCH}."
    echo "Pour construire à partir des sources, allez dans $REPO_URL"
    sortie 1
  Fi

  si ! tapez "curl" > /dev/null && ! tapez "wget" > /dev/null ; alors
    echo "Soit curl ou wget est requis"
    sortie 1
  Fi
}

# checkK3dInstalledVersion vérifie quelle version de k3d est installée et
# s'il doit être modifié.
checkK3dVersionInstallée() {
  if [[ -f "${K3D_INSTALL_DIR}/${APP_NAME}" ]] ; alors
    version locale=$(version k3d | grep 'version k3d' | cut -d " " -f3)
    if [[ "$version" == "$TAG" ]]; alors
      echo "k3d ${version} est déjà ${DESIRED_VERSION:-latest}"
      retourner 0
    autre
      echo "k3d ${TAG} est disponible. Changement depuis la version ${version}."
      retour 1
    Fi
  autre
    retour 1
  Fi
}

# checkTagProvided vérifie si TAG a été fourni en tant que variable d'environnement afin que nous puissions ignorer checkLatestVersion.
checkTagProvided() {
  [[ ! -z "$TAG" ]]
}

# checkLatestVersion récupère la dernière chaîne de version des versions
checkDernièreVersion() {
  local last_release_url="$REPO_URL/releases/latest"
  si tapez "curl" > /dev/null ; alors
    TAG=$(curl -Ls -o /dev/null -w %{url_effective} $latest_release_url | grep -oE "[^/]+$" )
  elif tapez "wget" > /dev/null ; alors
    TAG=$(wget $latest_release_url --server-response -O /dev/null 2>&1 | awk '/^\s*Emplacement : /{DEST=$2} END{ print DEST}' | grep -oE "[^ /]+$")
  Fi
}

# downloadFile télécharge le dernier package binaire ainsi que la somme de contrôle
# pour ce binaire.
télécharger un fichier() {
  K3D_DIST="k3d-$OS-$ARCH"
  DOWNLOAD_URL="$REPO_URL/releases/download/$TAG/$K3D_DIST"
  K3D_TMP_ROOT="$(mktemp -dt k3d-binaire-XXXXXX)"
  K3D_TMP_FILE="$K3D_TMP_ROOT/$K3D_DIST"
  si tapez "curl" > /dev/null ; alors
    curl -SsL "$DOWNLOAD_URL" -o "$K3D_TMP_FILE"
  elif tapez "wget" > /dev/null ; alors
    wget -q -O "$K3D_TMP_FILE" "$DOWNLOAD_URL"
  Fi
}

# installFile vérifie le SHA256 du fichier, puis décompresse et
# l'installe.
fichierinstall() {
  echo "Préparation de l'installation de $APP_NAME dans ${K3D_INSTALL_DIR}"
  runAsRoot chmod +x "$K3D_TMP_FILE"
  runAsRoot cp "$K3D_TMP_FILE" "$K3D_INSTALL_DIR/$APP_NAME"
  echo "$APP_NAME installé dans $K3D_INSTALL_DIR/$APP_NAME"
}

# fail_trap est exécuté si une erreur se produit.
fail_trap() {
  résultat=$?
  if [ "$résultat" != "0" ]; alors
    if [[ -n "$INPUT_ARGUMENTS" ]] ; alors
      echo "Impossible d'installer $APP_NAME avec les arguments fournis : $INPUT_ARGUMENTS"
      aider
    autre
      echo "Impossible d'installer $APP_NAME"
    Fi
    echo -e "\tPour le support, allez à $REPO_URL."
  Fi
  nettoyer
  sortie $résultat
}

# testVersion teste le client installé pour s'assurer qu'il fonctionne.
TestVersion() {
  si ! commande -v $APP_NAME &> /dev/null; alors
    echo "$APP_NAME introuvable. Est-ce que $K3D_INSTALL_DIR est sur votre "'$PATH ?'
    sortie 1
  Fi
  echo "Exécutez '$APP_NAME --help' pour voir ce que vous pouvez en faire."
}

# help fournit des arguments d'installation cli possibles
aider () {
  echo "Les arguments cli acceptés sont :"
  echo -e "\t[--help|-h ] ->> affiche cette aide"
  echo -e "\t[--no-sudo] ->> installer sans sudo"
}

# nettoyer les fichiers temporaires
nettoyer() {
  if [[ -d "${K3D_TMP_ROOT:-}" ]] ; alors
    rm -rf "$K3D_TMP_ROOT"
  Fi
}

# Exécution

#Arrêter l'exécution en cas d'erreur
trap "fail_trap" SORTIE
définir -e

# Analyse des arguments d'entrée (le cas échéant)
exporter INPUT_ARGUMENTS="${@}"
définir -u
while [[ $# -gt 0 ]]; faire
  cas $1 dans
    '--pas-sudo')
       USE_SUDO="faux"
       ;;
    '--aide'|-h)
       aider
       sortie 0
       ;;
    *) sortie 1
       ;;
  esac
  décalage
terminé
définir +u

initArch
initOS
vérifierPrise en charge
checkTagProvided || checkDernièreVersion
si ! checkK3dVersionInstallée; alors
  télécharger un fichier
  fichier d'installation
Fi
testVersion
nettoyer
