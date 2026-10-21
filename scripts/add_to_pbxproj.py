#!/usr/bin/env python3
"""Register Swift files in nightguard.xcodeproj without opening Xcode.

usage: add_to_pbxproj.py <group-name> <group-path> <app|tests|uitests>[,<...>] file1.swift [file2.swift ...]
"""
import hashlib, re, sys

PBX = "nightguard.xcodeproj/project.pbxproj"
GROUPS = {"app": "43647BCC1BFF6435004389F9", "tests": "43647BE11BFF6435004389F9", "uitests": "43647BEC1BFF6435004389F9"}
SOURCES = {"app": "43647BC61BFF6435004389F9", "tests": "43647BDA1BFF6435004389F9", "uitests": "43647BE51BFF6435004389F9"}

def uid(*parts):
    return hashlib.sha1("|".join(parts).encode()).hexdigest()[:24].upper()

def main():
    group_name, group_path, targets, files = sys.argv[1], sys.argv[2], sys.argv[3].split(","), sys.argv[4:]
    src = open(PBX).read()
    group_id = uid("group", group_path)
    parent_group = GROUPS[targets[0]]
    if group_id not in src and group_path:
        children = "\n".join(f"\t\t\t\t{uid('ref', group_path, f)} /* {f} */," for f in files)
        block = (f"\t\t{group_id} /* {group_name} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{children}\n\t\t\t);\n"
                 f"\t\t\tpath = {group_path};\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n")
        src = src.replace("/* Begin PBXGroup section */\n", "/* Begin PBXGroup section */\n" + block, 1)
        src = re.sub(rf"({parent_group} /\* \w+ \*/ = \{{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)",
                     rf"\g<1>\t\t\t\t{group_id} /* {group_name} */,\n", src, count=1)
    for f in files:
        ref = uid("ref", group_path, f)
        if ref not in src:
            src = src.replace("/* Begin PBXFileReference section */\n",
                f"/* Begin PBXFileReference section */\n\t\t{ref} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = \"<group>\"; }};\n", 1)
            if not group_path:
                src = re.sub(rf"({parent_group} /\* \w+ \*/ = \{{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)",
                             rf"\g<1>\t\t\t\t{ref} /* {f} */,\n", src, count=1)
            elif group_id in src and f"{ref} /* {f} */," not in src:
                src = re.sub(rf"({group_id} /\* {group_name} \*/ = \{{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)",
                             rf"\g<1>\t\t\t\t{ref} /* {f} */,\n", src, count=1)
        for t in targets:
            bf = uid("build", t, group_path, f)
            if bf in src:
                continue
            src = src.replace("/* Begin PBXBuildFile section */\n",
                f"/* Begin PBXBuildFile section */\n\t\t{bf} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {f} */; }};\n", 1)
            src = re.sub(rf"({SOURCES[t]} /\* Sources \*/ = \{{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = \d+;\n\t\t\tfiles = \(\n)",
                         rf"\g<1>\t\t\t\t{bf} /* {f} in Sources */,\n", src, count=1)
    open(PBX, "w").write(src)

if __name__ == "__main__":
    main()
