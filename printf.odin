package main

import "core:os"

// THE INTERNAL BUFFER
// Real printf implementations use buffering to avoid calling the OS
// for every single character, which would be incredibly slow.
BUFFER_SIZE :: 1024
buffer: [BUFFER_SIZE]u8
buf_idx := 0

// 1. THE API
// The "Magic" of Variadic Functions.
// In C, this relies on stack pointer arithmetic (va_list).
// In Odin, `..any` creates a slice of `any` structs, which hold {data_ptr, type_id}.
new_printf :: proc(format: string, args: ..any) {
	arg_idx := 0

	// We iterate manually to parse the string (The Template Engine)
	for i := 0; i < len(format); i += 1 {
		char := format[i]

		if char == '%' {
			// Safety check for end of string
			if i + 1 >= len(format) {
				emit_char(char)
				continue
			}

			// Peek next char to determine type
			i += 1
			specifier := format[i]

			// If we run out of args, just print the %? literal
			if arg_idx >= len(args) {
				emit_char('%')
				emit_char(specifier)
				continue
			}

			// 2. THE INTERNALS (Type Switching)
			// Here we walk the memory of the arguments provided.
			// Depending on the flag, we interpret the bits differently.
			current_arg := args[arg_idx]
			arg_idx += 1

			switch specifier {
			case 'd':
				// Handle Integers
				val: i64
				if v, ok := current_arg.(int);
				   ok {val = i64(v)} else if v, ok := current_arg.(i64); ok {val = v} else if v, ok := current_arg.(i32); ok {val = i64(v)}
				emit_int(val)
			case 's':
				// Handle Strings
				if v, ok := current_arg.(string); ok {
					emit_string(v)
				} else if v, ok := current_arg.(cstring); ok {
					emit_string(string(v))
				}
			case 'c':
				// Handle Chars
				if v, ok := current_arg.(rune); ok {
					emit_char(u8(v))
				} else if v, ok := current_arg.(u8); ok {
					emit_char(v)
				}
			case '%':
				emit_char('%')
				arg_idx -= 1 // We didn't actually consume an arg
			case:
				// Unknown specifier, print raw
				emit_char('%')
				emit_char(specifier)
			}
		} else {
			// Standard character
			emit_char(char)
		}
	}

	// Flush whatever remains in the buffer at the end
	flush_buffer()
}

// ---------------------------------------------------------
// HELPERS
// ---------------------------------------------------------

// Adds a character to the buffer. Flushes if full.
emit_char :: proc(c: u8) {
	if buf_idx >= BUFFER_SIZE {
		flush_buffer()
	}
	buffer[buf_idx] = c
	buf_idx += 1
}

emit_string :: proc(s: string) {
	for i := 0; i < len(s); i += 1 {
		emit_char(s[i])
	}
}

// Manual Integer to ASCII conversion (itoa)
// Because the computer only knows binary, we must do math
// to figure out which ASCII characters represent the number.
emit_int :: proc(n: i64) {
	if n == 0 {
		emit_char('0')
		return
	}

	num := n
	if num < 0 {
		emit_char('-')
		num = -num
	}

	// Extract digits in reverse order
	digits: [20]u8 // Max digits for i64 is 19 + sign
	count := 0

	for num > 0 {
		digit := num % 10
		digits[count] = u8(digit) + '0' // Convert 0-9 to ASCII '0'-'9'
		num /= 10
		count += 1
	}

	// Print them in correct order
	for i := count - 1; i >= 0; i -= 1 {
		emit_char(digits[i])
	}
}

// 3. THE SYSCALL
// This is where the code leaves user-space and talks to the Kernel.
// In C this is `write(1, buffer, len)`.
// `os.write` is a thin wrapper around the specific OS syscall
// (sys_write on Linux, WriteFile on Windows).
flush_buffer :: proc() {
	if buf_idx > 0 {
		// handle 1 is Stdout
		os.write(os.stdout, buffer[:buf_idx])
		buf_idx = 0
	}
}

// ---------------------------------------------------------
// MAIN
// ---------------------------------------------------------
main :: proc() {
	// Let's test our magical function
	new_printf("Hello, %s! The year is %d.\n", "World", 2025)

	new_printf("Internal check: char='%c', negative=%d\n", 'A', -42)

	// Demonstrate buffering: This string is long, but it will be batched
	new_printf("This is a demonstration of how %s works under the hood.\n", "printf")

	// We can even try it with even longer strings
	new_printf(
		"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
	)
}
