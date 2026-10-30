# may-the-forth

Installs the complete `may-the-forth-be-with-you` source tree, its compilers,
runners, BCC probe tooling, examples, documentation, and built artifacts.

The source tree is bundled with the role, making the installation
self-contained. The role copies it to `/opt/may-the-forth-be-with-you` and runs
`make build` when its contents change.

```yaml
- hosts: homebase
  roles:
    - role: may-the-forth
```

Set `may_the_forth_build_target: check` to run the full build and regression
suite during installation, or `may_the_forth_build: false` to install without
building.

