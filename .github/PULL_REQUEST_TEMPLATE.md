## Summary

Describe what this pull request changes and why.

## Related issue

Link the issue if one exists.

## Type of change

- [ ] Bug fix
- [ ] Documentation
- [ ] New module or feature
- [ ] Refactor or maintenance
- [ ] Test improvement

## Testing

- [ ] `bash scripts/lint.sh` passes
- [ ] `bash tests/test-install.sh` passes
- [ ] `./install.sh --check` works on an Arch system
- [ ] `./install.sh --dry-run --full` works on an Arch system
- [ ] The affected module was tested on real hardware or a virtual machine (if behavior changed)

## Safety checklist

- [ ] No `--noconfirm` flags were added
- [ ] No destructive disk, partition, or bootloader commands were added
- [ ] Every system-changing command respects `DRY_RUN`
- [ ] Existing user configuration is not overwritten
- [ ] No secrets, tokens, private logs, or personal data are included

## Notes

Add anything reviewers should know, including hardware that still needs testing.
