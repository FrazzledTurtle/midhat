# Command Metadata

Read this before adding or changing commands in `bin/`.

Commands in `bin/` can declare CLI metadata in comments near the top of the
file. `bin/midhat` scans the first 80 lines, and tests expect command metadata
to remain valid.

Supported metadata keys:

- `# midhat:group=...` - override the command group inferred from the filename
- `# midhat:name=...` - override the command name inferred from the filename
- `# midhat:summary=...` - short help text
- `# midhat:args=...` - usage arguments
- `# midhat:examples=...` - examples separated with ` | `
- `# midhat:alias=...` / `# midhat:aliases=...` - alternate routes
- `# midhat:hidden=true` - hide from default command listings
- `# midhat:requires-sudo=true` - mark commands that require sudo

Only use `midhat:examples` where there are args that need explaining.

Prefer explicit metadata for user-facing commands. Keep routes consistent with
the filename unless there is a deliberate alias or compatibility route.

Example:

```bash
# midhat:summary=Take a screenshot
# midhat:args=[smart|region|windows|fullscreen] [slurp|copy]
# midhat:examples=midhat screenshot | midhat capture screenshot region
```
