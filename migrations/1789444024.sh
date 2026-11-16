echo "Install missing headers for the Mid’hat or T2 kernel"

# Fresh ISO installs mark earlier migrations complete, so the kernel migration
# cannot repair headers omitted by those installers. Package installation is
# idempotent when another user has already applied this repair.
for kernel in linux-midhat linux-t2; do
  if midhat-pkg-present "$kernel"; then
    midhat-pkg-add "$kernel-headers"
  fi
done
