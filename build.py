import os

version = "1.3.2"
windows_path = f"%localappdata%/Roblox/Plugins/GapFill {version}.rbxmx"
posix_path = f"~/Documents/Roblox/Plugins/GapFill {version}.rbxmx"

if os.name == "nt":
	os.system(f"rojo build . -o \"{windows_path}\"")
else:
	os.system(f"rojo build . -o \"{posix_path}\"")