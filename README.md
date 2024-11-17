# Simple CSS parser written in Zig

Small project inspired in this one:
[Metaprogramming in Zig and parsing a bit of CSS](https://github.com/eatonphil/zig-metaprogramming-css-parser).

```console
$ zig build --summary all
$ ./zig-out/bin/css-parser tests/more-complete-2.css

selectors: "h1"
  text-align: "center"

selectors: ".container"
  background-color: "rgb(255, 255, 255)"
  padding: "10px 0"

selectors: ".marker"
  width: "200px"
  height: "25px"
  margin: "10px auto"

selectors: ".cap"
  width: "60px"
  height: "25px"

selectors: ".sleeve"
  width: "110px"
  height: "25px"
  background-color: "rgba(255, 255, 255, 0.5)"
  border-left: "10px double rgba(0, 0, 0, 0.75)"

selectors: ".cap", ".sleeve"
  display: "inline-block"

selectors: ".red"
  background: "linear-gradient(rgb(122, 74, 14), rgb(245, 62, 113), rgb(162, 27, 27))"
  box-shadow: "0 0 20px 0 rgba(83, 14, 14, 0.8)"

selectors: ".green"
  background: "linear-gradient(#55680D, #71F53E, #116C31)"
  box-shadow: "0 0 20px 0 #3B7E20CC"

selectors: ".blue"
  background: "linear-gradient(hsl(186, 76%, 16%), hsl(223, 90%, 60%), hsl(240, 56%, 42%))"
  box-shadow: "0 0 20px 0 blue"
```
