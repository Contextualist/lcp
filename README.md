# lcp

`lcp` makes file transfer between two users in a LAN as simple as `cp`. It aims to fill the niche of file transfer where tools such as `scp` and `rsync` are a little bit cumbersome. I'd like to call it "the AirDrop for cli", because the receiver can choose what to do with the files for each tranfer.

## Usage

A light-weight tool for light-weight scenarios, `lcp` is a bash script (~170L) that establishes **UNAUTHED** and **UNENCRYPTED** connections for transfer. Even though you can use `lcp` as long as the receiver's port is accessible, **it is strongly advised to be used only in trusted local network**. (Disscussions of how to enhance security without significant UX tradeoff are welcomed!)

```bash
# Sender
> lcp data/001/ recv.local

# Receiver (i.e. recv.local)
> ls
> lcp -d 001-s
> ls
001-s


# Clipboard sharing (optional)
# Sender
> lcp -c recv.local

# Receiver
> lcp # Now Receiver can paste what Sender has copied!
```

It doesn't matter who takes action first. `lcp` can negotiates and establishes a connection in either situation. The hostnames are long? `lcp` also take custom aliases. For more options see `lcp -h`.

## Install

I try to make it compatible with major \*nix platforms. Compatibility issues/PRs are welcomed!

```bash
# If you want the clipboard integration, set env `LCP_CLIPBOARD` to 1 in your shell profile first.
bash <(curl -Ls https://lcp.now.sh/get)
```

The install script downloads `lcp`, checks for dependencies: `nc` (and `xclip`/`xsel`/`pbcopy` if clipboard integration is enabled), and compiles the missing ones.

`lcp` stores hostname aliases in `~/.config/lcphosts`. If you want to view your hostname every time pending on receiving (useful if it is transient), set env `LCP_DISPLAYHOST` to 1.

## Difference with `cp`

`cp` doesn't allow operations like `cp more than one file dir_not_exist`, while `lcp` will try to create the directory `dir_not_exist` in this situation. If `dir_not_exist` is a name taken by a file, `lcp` will create a directory with random name in the same parent directory.
