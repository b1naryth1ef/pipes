# Pipes

Pipes is a command line utility to make common unix scripting tasks easier and faster. Pipes is targeted at unix users who are looking to extend or augment their bash scripting ability via a terse, modern and logical programming language. Pipes is stream based which aligns well with the unix and bash data flow methodologies.

## Examples

```sh
$ cat 'students.csv' > pipes 'csv.lines @> skip(1) |> equals($1, 'Student') |> $3 => average
16.4

$ cat 'logs.txt' > pipes 'lines @> extract('((?:[0-9]{1,3}\.){3}[0-9]{1,3})') => occurences
192.168.1.2 12234
192.168.1.1 233

$ dirs @> fs.find(f'$1/*.rar') -> index(0) -> pushd(path.dir($1)) |> path.file($1) -> try(exec(f'unrar x $1')) |> fs.find(f'*.[mkv|mov|mp4|avi]') @> try(exec(f'mv $1 /media/storage/Movies/'))
```

## Data Flow

Understanding how data flows in a pipes program or script is crucial to understanding pipes itself. Pipe can recieve data from stdin like a traditional unix program. Additionally its possible to use some of pipes standard library functionality to load data. Once in pipes data will generally flow through a "stream" which has various nodes that can map, reduce, process and output data.

## Performance

Pipes supports compiling a program down to machine code via LLVM. This can be extremely useful when processing large amounts of data or running complex programs.

## Operators

| Operator | Name | Description |
|----------|------|-------------|
| @> | Map | Maps a enumerable data structure into a stream. |
| -> | Pass | Passes data from one leg of a stream to another. |
| => | Reduce | Reduces a stream of data into a single enumerable. |
| \|> | Continue | Passes the previous steps output into the subsequent step. |
