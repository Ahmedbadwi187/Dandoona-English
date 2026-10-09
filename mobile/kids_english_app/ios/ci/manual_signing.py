"""CI only: switch the Runner app target to manual signing with this run's App Store profile (the file in the repo stays on
automatic signing for building on a Mac). Usage: manual_signing.py TEAM_ID PROFILE_NAME"""
import re, sys

team, profile = sys.argv[1], sys.argv[2]
path = "ios/Runner.xcodeproj/project.pbxproj"
text = open(path).read()
settings = {
    "CODE_SIGN_STYLE": "Manual",
    "DEVELOPMENT_TEAM": team,
    "PROVISIONING_PROFILE_SPECIFIER": f'"{profile}"',
    "CODE_SIGN_IDENTITY": '"Apple Distribution"',
    '"CODE_SIGN_IDENTITY[sdk=iphoneos*]"': '"Apple Distribution"',
}
count = 0


def patch(block):
    global count
    body = block.group(0)
    if "PRODUCT_BUNDLE_IDENTIFIER = com.dandoona.kidsEnglishApp;" not in body:
        return body  # other targets (tests) and project-level configurations stay as they are
    for key, value in settings.items():
        body = re.sub(rf"\n\t*{re.escape(key)} = [^;]*;", "", body)
    extra = "".join(f"\n\t\t\t\t{k} = {v};" for k, v in settings.items())
    body = body.replace("buildSettings = {", "buildSettings = {" + extra, 1)
    count += 1
    return body


text = re.sub(r"isa = XCBuildConfiguration;.*?name = \w+;", patch, text, flags=re.S)
if count != 3:
    sys.exit(f"Expected the 3 Runner configurations, found {count}")
open(path, "w").write(text)
print(f"Runner target: manual signing with '{profile}' ({count} configurations)")
