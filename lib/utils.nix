{ lib, ... }:
rec {
  mkModule =
    {
      config,
      category,
      name,
      description,
      extraOptions ? { },
      moduleConfig ? { },
    }:
    {
      options.nc.${category}.${name} = lib.mkMerge [
        {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            inherit description;
          };
        }
        extraOptions
      ];

      config = lib.mkIf config.nc.${category}.${name}.enable moduleConfig;
    };

  isEnabled =
    attr: config: default:
    assert lib.isString attr || lib.isList attr;
    let
      path = if builtins.isList attr then attr else lib.splitString "." attr;
    in
    lib.attrByPath path default config;

  packages = {
    home =
      {
        always ? [ ],
        gui ? [ ],
        extra ? [ ],
      }:
      config:
      assert lib.isList always;
      assert lib.isList gui;
      assert lib.isList extra || lib.isAttrs extra;
      let
        guiEnabled = isEnabled "home.gui.enable" config false;
        extraPackages =
          if builtins.isAttrs extra then
            (extra.always or [ ]) ++ (lib.optionals guiEnabled (extra.gui or [ ]))
          else
            extra;
      in
      always ++ (lib.optionals guiEnabled gui) ++ extraPackages;
    system =
      {
        base ? [ ],
        extra ? [ ],
      }:
      base ++ extra;
  };

}
