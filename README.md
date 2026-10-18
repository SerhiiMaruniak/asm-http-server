# Minimal Assembly HTTP Server

A small experimental HTTP server written in x86-64 assembly. It runs on Linux and makes direct system calls without libc or third-party libraries.

## Features

- Listens on TCP port **80** on all network interfaces.
- Handles each incoming connection in a separate child process.
- **GET**: reads a file at the path from the URL, relative to the current working directory, and sends its contents.
- **POST**: writes the request body to the file at the path from the URL. The file is created if it does not already exist.
- Sends `HTTP/1.0 200 OK` for successful responses.

## Requirements

- Linux on x86-64.
- GCC and GNU assembler (typically provided by the `build-essential` package on Debian/Ubuntu).

The code uses Linux x86-64 system call numbers and is not intended for macOS or Windows.

## Build

From the project root, run:

```sh
gcc -nostdlib -no-pie -o web_server server.s
```

The `-nostdlib` option builds the program without the standard library: the `_start` entry point and system calls are implemented in `server.s`.

## Run

The server uses port 80, which usually requires administrator privileges on Linux:

```sh
sudo ./web_server
```

The server runs in the foreground. Stop it with `Ctrl+C`.

## Example requests

File paths are resolved relative to the directory from which the server was started. For example, to read `index.html`:

```sh
curl http://127.0.0.1/index.html
```

To send the contents of `message.txt` and write them to `uploads/message.txt`:

```sh
mkdir -p uploads
curl --data-binary @message.txt http://127.0.0.1/uploads/message.txt
```

## How it works

On startup, the program creates an IPv4 TCP socket, binds it to port 80, and waits for connections. For each accepted connection, the server calls `fork`: the parent process continues accepting clients, while the child reads the request, determines the method and path, performs the file operation, and sends a response.
