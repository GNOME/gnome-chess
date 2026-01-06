# GNOME Chess

GNOME Chess is a 2D chess game, where games can be played between a combination of human and computer players.
GNOME Chess detects known third party chess engines for computer players.

<a href='https://flathub.org/apps/details/org.gnome.Chess'><img width='240' alt='Download on Flathub' src='https://flathub.org/assets/badges/flathub-badge-i-en.png'/></a>

## Building GNOME Chess

In order to build the program, we can use [Flatpak](https://docs.flatpak.org/en/latest/introduction.html) and [Flatpak Builder](https://docs.flatpak.org/en/latest/flatpak-builder.html).

To install Flatpak Builder, we need to add Flathub as a remote first:

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

Then, run the command below:

```bash
flatpak install flathub org.flatpak.Builder
```

GNOME Chess depends on [GNOME Nightly](https://nightly.gnome.org/). To add the remote to your system, run the command below:

```bash
flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo
```

Once the remote was added, we'll need to install both GNOME Platform and GNOME SDK:

```bash
flatpak install gnome-nightly org.gnome.Platform//master
flatpak install gnome-nightly org.gnome.Sdk//master
```

Once everything is properly installed, you can `git clone` this repo on your machine in any desired folder with the following command:

```bash
git clone https://gitlab.gnome.org/GNOME/gnome-chess.git
```

Then, in order to build GNOME Chess, run the following command:

```bash
flatpak run org.flatpak.Builder --force-clean --install --repo=./repo ./build ./gnome-chess/org.gnome.Chess.json
```

If everything was successful, you should be able to run GNOME Chess with the following command:

```bash
flatpak run org.gnome.Chess
```

## Useful links

- Report issues: <https://gitlab.gnome.org/GNOME/gnome-chess/issues/>
- Donate: <https://donate.gnome.org/>
