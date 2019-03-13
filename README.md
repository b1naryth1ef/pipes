# Pipes

> Pipes is currently being developed and probably doesn't work how you'd like it too.

Pipes is a small data processing language that is designed to be used on the command line. Pipes distills the functional data processing capabilities of tools like bash into a simple self contained language. Pipes is targeted towards users who find themselves loving data processing in bash but want a more efficient and consistent toolset.

## Why a new language?

While pipes is an entirely self contained programming language it lacks almost all of the cool modern programming language features. Pipes is more oriented around providing a mechanism to express programs in a style thats parallel to how data flows and is processed. Personally this provides some nice advantages and clarity when programming in an exploratory or investigatory fashion.

Another advantage of building a programming language, is that it allows for easy performance wins and optimizations. By utilizing the great LLVM toolchain pipes gains a lot of performance that would have otherwise been lost to the flexibility it provides.

## A Simple Example

Lets take a look at a simple pipes program and break it down to understand the mechanisms behind pipes.

```sh
$ acpi | ./pipes "lines -> reStream('Battery (\d+): .* (\d+)%') -> takeString(2) @> echo"
100
100
```

First we should exam our input which in this case is just the output of the `acpi` command on Linux:

```
Battery 0: Full, 100%
Battery 1: Full, 100%
```

The first thing our pipes program does is call the function 'lines'. This function splits stdin by newlines and sends the data through a stream of strings. Streams in pipes can be thought of as unbounded, ordered sets of data (very similar to generators in Python).

Next our program passes this stream into another function `reStream` alongside a string argument. When using the pass operator (`->`) the result of the last step in our program will automatically be passed as the first argument to the current step. Due to this our program now actually looks something like:

```
reStream(lines(), 'Battery (\d+): .* (\d+)%')
```

The `reStream` function itself takes a stream of strings and a regex pattern. In return it provides a stream of arrays containing some number of string elements. In our case each array will contain three string elements:

1. Our full regex match: `Battery 0: Full, 100%`
2. The first regex group: `0`
3. The second regex group: `100`

Next our program passes this stream into another function `takeString`. This function returns a stream of strings containing the second element of each array passed in. Its worth noting that this function will work for arrays that contain various lengths, in the case that the index doesn't exist because the array is too small the upstream array will simply be skipped. Finally our program maps the result of this stream into the echo function. The map operator simply enumerates over a stream/array/etc, passing each element to the next step.

An important detail of this program is a design choice taken by the original programmer to keep data within streams until the end. This program could have also been written like the following:

```
$ acpi | ./pipes "lines @> re('Battery (\d+): .* (\d+)%') -> ^2 -> echo"
```

However our original program gains some nice performance by utilizing `reStream` which avoids recompiling our regex for each element. Obviously in this convoluted example this has almost zero impact on the execution of the program itself but its important to consider these properties when building programs that process large amounts of data.

##  Operators

| Operator | Name | Description |
|----------|------|-------------|
| @> | Map | Maps a enumerable data structure into a stream. |
| -> | Pass | Passes data from one leg of a stream to another. |
| => | Reduce | Reduces a stream of data into a single enumerable. |
| \|> | Continue | Passes the previous steps output into the subsequent step. |
