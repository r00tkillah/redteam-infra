# Smugglebus

Installs smugglebus, a command-line HTML smuggling utility.

The role copies its vendored smugglebus files to `/opt/smugglebus`. The target does
not need Git access or Go build dependencies.

## Variables

- `smugglebus_install_dir`: Destination for the vendored files. Defaults to `/opt/smugglebus`.

## Example

```yaml
- hosts: homebase
  roles:
    - smugglebus
```
