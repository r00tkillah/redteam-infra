# Smugglebus

Smugglebus is a simple utility to implement HTML smuggling done by APT29 [^1][^2]

# Usage

```usage: smugglebus [-h|--help] -i|--input <file> -o|--output <file>
                  [-c|--iso9660] [-v|--isovolume "<value>"] [-f|--dropped-name
                  "<value>"]

                  Creates HTML attachment for HTML smuggling

Arguments:

  -h  --help          Print help information
  -i  --input         Input filename to smuggle
  -o  --output        Output filename to generate
  -c  --iso9660       Encode in iso9660 format. Default: false
  -v  --isovolume     Volume name for ISO9660 image, if enabled. Default: DS
                      Installer
  -f  --dropped-name  Filename of dropped download file. Default: installer.iso

```



[^1] https://www.microsoft.com/security/blog/2021/05/27/new-sophisticated-email-based-attack-from-nobelium/
[^2] https://www.mandiant.com/resources/tracking-apt29-phishing-campaigns