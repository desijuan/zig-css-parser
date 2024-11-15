# Simple CSS parser written in Zig

Small project inspired in this one:
[Metaprogramming in Zig and parsing a bit of CSS](https://github.com/eatonphil/zig-metaprogramming-css-parser).

```console
$ zig build --summary all
$ ./zig-out/bin/css-parser tests/multiple-blocks.css

selector: "div"
  background: "black"
  color: "white"

selector: "a"
  color: "blue"

selector: "h1"
  color: "red"
  font-family: "sans-serif"

selector: ".center"
  display: "flex"
  justify-content: "center"
  align-items: "center"
  height: "100vh"

```
