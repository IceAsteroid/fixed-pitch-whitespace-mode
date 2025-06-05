# fixed-pitch-whitespace-mode: Fixed-pitch leading whitespaces in variable-pitch buffers.

The mode refontifies leading whitespaces(spaces & tabs) into fixed-pitch,
for `variable-pitch-mode`-enabled buffers.

## Motivation & Purposes
It's ineffecient for me to read monospace text, so I want to turn most text
buffers in modes that displays literal text such as the `Info-mode`, `org-mode`
to display in `variable-pitch-mode`, which displays most text in a variable
font

*Note*: The variable font and monospace font can be set respectively in the `variable-pitch` and `fixed-pitch` faces for `variable-pitch-mode`.

However, I found it was difficult to differentiate distinct levels of
indentations for a `variable-pitch-mode` enabled buffer, the leading spaces and
tabs are displayed in a variable font.

What I want is all characters inluding the spaces & tabs displayed in a variable
font while only the leading spaces & tabs are displayed in a monospace
font(elements in a buffer that has `fixed-pitch` face).

## Use cases
This mode is helpful when enabled in `Info-mode` and `org-mode`. which are the current use
cases as my daily driver.

## Compatibility & Performance
Works well among different themes, as some themes for org-mode do not fontify the source
block headers into variable-pitch, but some do. The mode refontifies via `jit-lock` by
checking the leading whitepsaces of each line are in fixed-pitch or not, if not, refontifies
them. Instead of checking whether a line is in a org block that is displayed in fixed-pitch
or not, which is significantly more inefficient.

The code is optimized with performance in mind, which elimites unnecessary overhad as much as
possible.

The tab-character-included buffers and non-tab-inlucded buffers are
differentiated underlyingly to search and refontify for, so a buffer if tested
is without tabs in it and also without `indent-tabs-mode` turned on, it's gonna be slightly
faster, though not noticable at all except for enormous large buffers.

Toggling `indent-tabs-mode` triggers a re-testing for tabs and non-tabs as set
in `indent-tabs-mode-hook`.

Please, **let me know** if you know there's a way that provides better performance.

## About the global & local modes in this package
This package provides both the local & global modes.

The local mode `fixed-pitch-whitespace-local-mode` can be turned on specifically
for a buffer, that does not differentiate whether it's a `variable-pitch-mode`
enabled buffer or not. (Use with care as some buffers witout
`variable-pitch-mode` may behave weirdly)

The global mode `fixed-pitch-whitespace-global-mode` can be turned on, which
enables the mode for buffers that has `variable-pitch-mode` enabled.
