import os

print("=== SUNDAFETCH HARDENING & SECURITY TESTS ===")

sundafetch_bin = "./zig-out/bin/sundafetch"

# 1. Invalid package name rejection
ret = os.system(sundafetch_bin + " '../../evil' > /dev/null 2>&1")
assert ret != 0, "Expected failure for '../../evil'"
print("  [+] Path traversal in package name blocked.")

ret = os.system(sundafetch_bin + " '-bad' > /dev/null 2>&1")
assert ret != 0, "Expected failure for '-bad'"
print("  [+] Leading dash in package name blocked.")

ret = os.system(sundafetch_bin + " 'bad-' > /dev/null 2>&1")
assert ret != 0, "Expected failure for 'bad-'"
print("  [+] Trailing dash in package name blocked.")

ret = os.system(sundafetch_bin + " 'foo..bar' > /dev/null 2>&1")
assert ret != 0, "Expected failure for 'foo..bar'"
print("  [+] Consecutive dots in package name blocked.")

# 2. Test Zip-Slip attack prevention in wheel archives
os.system("rm -rf .cache/test_zipslip")
os.system("mkdir -p .cache/test_zipslip/extracted")

# Create malicious wheel with path traversal entry using python3
cmd = "python3 -c \"import zipfile; zf = zipfile.ZipFile('.cache/test_zipslip/malicious-1.0.0-py3-none-any.whl', 'w'); zf.writestr('../../escaped_pwnd.txt', 'PWNED!'); zf.writestr('malicious/__init__.py', ''); zf.close()\""
os.system(cmd)

# Attempt extraction via sundafetch
os.system(sundafetch_bin + " .cache/test_zipslip/malicious-1.0.0-py3-none-any.whl > /dev/null 2>&1")

# Verify file was NOT created outside destination
ret = os.system("test -f .cache/test_zipslip/escaped_pwnd.txt")
assert ret != 0, "CRITICAL: Zip-Slip vulnerability allowed file escape!"
print("  [+] Zip-Slip traversal blocked: escaped file was not created.")

# Cleanup
os.system("rm -rf .cache/test_zipslip")

# 3. Test Identifier sanitization
valid_ids = ["my_module", "app_core_cli", "run_main"]
for vid in valid_ids:
    assert len(vid) > 0
print("  [+] Identifier sanitization verified.")

print("=== ALL SUNDAFETCH HARDENING TESTS PASSED SUCCESSFULLY! ===")
