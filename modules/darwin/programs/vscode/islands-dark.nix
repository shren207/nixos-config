# Islands Dark VSCode theme integration.
# Keep source packaging and VSCode CSS patching out of the main HM module.
{
  lib,
  pkgs,
  source,
  vscodePackage ? pkgs.vscode,
}:

let
  packageJson = builtins.fromJSON (builtins.readFile "${source}/package.json");
  settingsJson = builtins.fromJSON (builtins.readFile "${source}/settings.json");

  expectedPublisher = "bwya77";
  expectedName = "islands-dark";
  uniqueId = "${expectedPublisher}.${expectedName}";
  packageVersion =
    if packageJson.publisher != expectedPublisher || packageJson.name != expectedName then
      throw "Unexpected Islands Dark extension id: ${packageJson.publisher}.${packageJson.name}"
    else if builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" packageJson.version == null then
      throw "Unexpected Islands Dark extension version: ${packageJson.version}"
    else
      packageJson.version;

  stylesheet = settingsJson."custom-ui-style.stylesheet" or { };

  assertCssFragment =
    role: text:
    let
      lowerText = lib.toLower text;
      blockedExternal = lib.any (needle: lib.hasInfix needle lowerText) [
        "@import"
        "url("
        "http://"
        "https://"
        "file://"
      ];
      blockedStructure = lib.any (needle: lib.hasInfix needle text) [
        "{"
        "}"
        ";"
        "/*"
        "*/"
        "\n"
        "\r"
      ];
    in
    if blockedExternal || blockedStructure then
      throw "Islands Dark stylesheet contains blocked CSS ${role}: ${text}"
    else
      text;

  unsupportedStylesheetEntries = lib.filterAttrs (
    selector: rules: !(builtins.isAttrs rules) && !(lib.hasPrefix "//" selector)
  ) stylesheet;

  cssRules =
    if unsupportedStylesheetEntries != { } then
      throw "Islands Dark stylesheet contains unsupported non-object entries: ${lib.concatStringsSep ", " (builtins.attrNames unsupportedStylesheetEntries)}"
    else
      lib.filterAttrs (_selector: rules: builtins.isAttrs rules) stylesheet;

  cssValueToString =
    value:
    let
      type = builtins.typeOf value;
    in
    if type == "string" then
      assertCssFragment "value" value
    else if type == "int" || type == "float" || type == "bool" then
      toString value
    else
      throw "Islands Dark stylesheet contains unsupported CSS value type: ${type}";

  # Nix JSON parsing stores objects as attrsets, so selector/property source order is not preserved.
  # Keep this path for self-contained declarations that do not depend on equal-specificity cascade order.
  cssText = builtins.concatStringsSep "\n" (
    lib.mapAttrsToList (selector: rules: ''
      ${assertCssFragment "selector" selector} {
      ${builtins.concatStringsSep "\n" (
        lib.mapAttrsToList (
          prop: value: "  ${assertCssFragment "property" prop}: ${cssValueToString value};"
        ) rules
      )}
      }
    '') cssRules
  );

  cssFile = pkgs.writeText "islands-dark-vscode.css" cssText;

  extension = pkgs.stdenvNoCC.mkDerivation {
    pname = "vscode-extension-${expectedPublisher}-${expectedName}";
    version = packageVersion;
    src = source;

    installPhase = ''
      runHook preInstall

      extension_dir="$out/share/vscode/extensions/${uniqueId}"
      mkdir -p "$extension_dir"
      cp package.json "$extension_dir/"
      cp -r themes "$extension_dir/"
      if [ -f icon.png ]; then
        cp icon.png "$extension_dir/"
      fi

      runHook postInstall
    '';

    passthru = {
      vscodeExtUniqueId = uniqueId;
      vscodeExtPublisher = expectedPublisher;
      vscodeExtName = expectedName;
    };
  };

  fonts = {
    bearSansUi = pkgs.stdenvNoCC.mkDerivation {
      pname = "bear-sans-ui";
      version = packageVersion;
      src = "${source}/fonts";

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/share/fonts/opentype"
        cp *.otf "$out/share/fonts/opentype/"

        runHook postInstall
      '';
    };
  };

  package = vscodePackage.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      css_count=$(find "$out" -path '*/workbench.desktop.main.css' -type f -print | wc -l | tr -d ' ')
      if [ "$css_count" -ne 1 ]; then
        echo "Expected exactly one workbench.desktop.main.css in VSCode output, found $css_count" >&2
        find "$out" -path '*/workbench.desktop.main.css' -type f -print >&2
        exit 1
      fi

      css_file=$(find "$out" -path '*/workbench.desktop.main.css' -type f -print | head -n 1)
      cat ${cssFile} >> "$css_file"
    '';
  });
in
{
  inherit
    extension
    fonts
    package
    ;
}
