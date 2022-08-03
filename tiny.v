module main

import cli { Command, Flag }
import os
import net
import io

fn main() {
	mut cmd := Command{
		name: 'tiny'
		description: 'This is a tinyhttpd application.'
		version: '1.0.0'
	}
	mut run_cmd := Command{
		name: 'start'
		description: 'Prints greeting in different languages.'
		usage: '<name>'
		execute: greet_func
	}
	run_cmd.add_flag(Flag{
		flag: .int
		required: true
		name: 'port'
		abbrev: 'l'
		description: 'setup port.'
	})
	run_cmd.add_flag(Flag{
		flag: .string
		required: true
		name: 'path'
		abbrev: 'p'
		description: 'setup path.'
	})
	cmd.add_command(run_cmd)
	cmd.setup()
	cmd.parse(os.args)
}

fn greet_func(cmd Command) ? {
	port := cmd.flags.get_int('port') or { panic('Failed to get `port` flag: $err') }
	// println(port)
	path := cmd.flags.get_string('path') or { panic('Failed to get `path` flag: $err') }
	// println(path)
	startup(port, path)
}

fn startup(port int, path string) {
	mut server := net.listen_tcp(.ip, 'localhost:$port') or { return }
	laddr := server.addr() or { return }
	eprintln('Listen on $laddr ...')
	for {
		mut socket := server.accept() or { panic(err) }
		mut h := go handle_client(mut socket, path)
		h.wait()
	}
}

fn handle_client(mut socket net.TcpConn, gpath string) {
	defer {
		socket.close() or { panic(err) }
	}
	socket.peer_addr() or { return }
	mut reader := io.new_buffered_reader(reader: socket)
	defer {
		reader.free()
	}
	mut path := ''
	for {
		received_line := reader.read_line() or { return }
		if received_line == '' {
			if !os.exists(path) {
				socket.write_string(bad_request(404)) or { return }
			} else {
				t := os.read_bytes(path) or {
					socket.write_string(bad_request(500)) or { return }
					return
				}
				socket.write_string('HTTP/1.1 200 OK\r\n') or { return }
				socket.write_string('\r\n') or { return }
				socket.write(t) or { return }
			}
			socket.write_string('\r\n') or { return }
			return
		}
		params := received_line.split(' ')
		if ['POST', 'GET'].contains(params[0].to_upper()) {
			if params[1] == '/' {
				path = gpath + '/index.html'
			} else {
				path = gpath + params[1]
			}
		}
	}
}

fn bad_request(code int) string {
	match code {
		404 {
			return 'HTTP/1.1 404 NOT FOUND\r\n\r\n404 NOT FOUND\r\n'
		}
		500 {
			return 'HTTP/1.1 500 Internal Server Error\r\n\r\n500 Internal Server Error\r\n'
		}
		else {
			return 'UNKNOW\r\n\r\n'
		}
	}
}
