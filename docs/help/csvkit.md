# csvkit

Cat Food installs csvkit 2.2.0 as a Termux runtime helper on the Android phone and tablet.

It keeps the Python modules under `~/opt/packages/csvkit/2.2.0/site-packages` and exposes the upstream commands under `~/opt/bin`:

`csvclean`, `csvcut`, `csvformat`, `csvgrep`, `csvjoin`, `csvjson`, `csvlook`, `csvpy`, `csvsort`, `csvsql`, `csvstack`, `csvstat`, `in2csv`, and `sql2csv`.

The installer uses Termux `python` and `python-pip`, but installs them with package-manager recommendations disabled on apt-based Termux. In particular it does not install the `clang`, `make`, or `pkg-config` packages merely because `python-pip` recommends them.

The Python installation itself also uses `pip --only-binary=:all:`. If csvkit or one of its required dependencies stops publishing a compatible wheel, Cat Food fails rather than compiling that dependency on the phone or tablet.

For a CSV in the current directory:

```sh
csvlook file.csv
csvstat file.csv
csvcut -n file.csv
```

This helper is convenience software installed by the Cat Food control plane. It is not evidence that an Android product package in `android/packages.tsv` was built, published, or physically accepted.
