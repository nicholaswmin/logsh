[![tests](https://github.com/nicholaswmin/logsh/actions/workflows/test.yml/badge.svg)](https://github.com/nicholaswmin/logsh/actions/workflows/test.yml)

# logsh

[POSIX.1-2017 - 2001][psx] & [CLI guidelines][clg] compliant logger 

- semantic log coloring to `stderr`
- follows [NO_COLOR][ncl], [FORCE_COLOR][fcl], `DEBUG`, `QUIET`,
 `JSON` and `LOG_LEVEL` conventions.
 
```sh
. ./logsh/log.sh

log_info  "bootstrapping..."
log_warn  "fallback default"
log_done  "backup completed"

log_debug "reached codepath"
log_error "failed to update"

```

## Contents

- [Usage](#usage)
- [Configuration](#configuration)
- [Examples](#examples)
- [Testing](#testing)
- [License](#license)

## Usage

get `log.sh`

```sh
curl -s "https://raw.githubusercontent.com/nicholaswmin/logsh/main/log.sh" -o log.sh
```

and source it:

```sh
. ./logsh/log.sh

# Log different types of messages
log_info "an informational message"
log_debug "a debug message (hidden by default)"
log_warn "a warning message"
log_error "an error message"
log_success "a success message"

# Or use a custom level
log "CUSTOM" "a custom level message"
```

## Configuration

use environment variables for configuration:

| Variable       | Description                           | Default |
|----------------|---------------------------------------|---------|
| `LOG_LEVEL`    | Filter by level (ERROR, WARN, INFO)   | INFO    |
| `DEBUG=1`      | Show debug output with level prefixes | -       |
| `QUIET=1`      | Suppress all non-error messages       | -       |
| `NO_COLOR=1`   | Disable colored output                | -       |
| `FORCE_COLOR=1`| Force colors in non-terminal envs.    | -       |
| `JSON=1`       | Output logs in JSON format            | -       |

### Custom Colors

colors can be customised for each log level:

```sh
# Example: Use custom colors
LOGCOL_INFO=$(tput setaf 7)      # White
LOGCOL_DEBUG=$(tput dim)         # Dim
LOGCOL_WARN=$(tput setaf 3)      # Yellow
LOGCOL_ERROR=$(tput setaf 1)     # Red
LOGCOL_SUCCESS=$(tput setaf 2)   # Green
LOGCOL_RESET=$(tput sgr0)        # Reset
```

> **note:** this increases performance by avoiding `tput` calls

## Examples

### Basic

```sh
. ./logsh/log.sh

log_info "bootstrapping..."
log_warn "config. file not found, fallback to defaults"
log_error "failed to update"
log_success "backup completed"
```

### JSON output

```sh
JSON=1 ./script-using-log.sh
```

Outputs logs in JSON format suitable for parsing:

```json
{ "level":"info","message":"bootstrapping..." }
{ "level":"warn","message":"fallback default" }
```

### CLI flags

See [cli.sh][csh] for a complete CLI example

### Timestamps

While not built-in, you can wrap it like so:

```sh
logt_info() { log_info "$(date '+%Y-%m-%d %H:%M:%S') - $*"; }
# also wrap: debug, warn ...
```
## Testing

requires [bats-core][btc]:

```sh
brew install bats-core
```

run the tests:

```sh
bats test
```

#### shellcheck

```sh
# install: brew install shellcheck
shellcheck --shell=sh log.sh
```


## License  

> MIT-0 License
>
> Copyright (c) 2025 @nicholaswmin
>
> Permission is hereby granted, free of charge, to any person
> obtaining a copy of this software and associated documentation
> files (the "Software"), to deal in the Software without
> restriction, including without limitation the rights to use, copy,
> modify, merge, publish, distribute, sublicense, and/or sell copies
> of the Software, and to permit persons to whom the Software is
> furnished to do so.

[ncl]: https://no-color.org/ 
[fcl]: https://force-color.org/
[clg]: https://clig.dev/
[btc]: https://bats-core.readthedocs.io/
[jso]: https://www.json.org/json-en.html
[lic]: https://choosealicense.com/licenses/mit-0/
[agh]: https://github.com/nicholaswmin
[psx]: https://ieeexplore.ieee.org/document/8372834
[csh]: ./cli.sh
