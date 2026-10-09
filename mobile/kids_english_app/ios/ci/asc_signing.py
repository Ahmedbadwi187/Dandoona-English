"""App Store signing for CI through the App Store Connect API (no Mac account login, no Xcode cloud signing).

  check    the key works, the Bundle ID is registered (registered if missing), the app exists in App Store Connect
  create   a distribution certificate (new private key + CSR) and an App Store profile for this run; writes signing.p12,
           profile.mobileprovision and state.json into OUT_DIR
  cleanup  deletes the profile and revokes the certificate made by `create` (apps already uploaded are not affected:
           Apple re-signs App Store / TestFlight builds)

Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (the .p8), BUNDLE_ID, OUT_DIR, P12_PASSWORD, RUN_NAME.
"""
import base64, json, os, sys, time, urllib.error, urllib.request

import jwt  # PyJWT
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID

API = "https://api.appstoreconnect.apple.com/v1"


def fail(msg):
    print(f"::error::{msg}")
    sys.exit(1)


MODE = {"individual": False}  # a Team key (iss = Issuer ID) unless Apple only accepts it as an Individual key (sub = "user")


def token():
    key = open(os.environ["ASC_KEY_PATH"]).read()
    if "BEGIN PRIVATE KEY" not in key or "END PRIVATE KEY" not in key:
        fail("ASC_KEY_P8 does not look like the whole .p8 file: copy everything from -----BEGIN PRIVATE KEY----- to the END line.")
    now = int(time.time())
    try:
        claims = {"iat": now, "exp": now + 1000, "aud": "appstoreconnect-v1"}
        claims.update({"sub": "user"} if MODE["individual"] else {"iss": os.environ["ASC_ISSUER_ID"].strip()})
        return jwt.encode(claims, key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"].strip(), "typ": "JWT"})
    except Exception as e:  # a broken key
        fail(f"The .p8 key in ASC_KEY_P8 cannot be read ({e.__class__.__name__}). Paste the whole file again.")


def call(method, path, body=None, ok=(200, 201, 204)):
    req = urllib.request.Request(API + path, method=method, data=None if body is None else json.dumps(body).encode(),
                                 headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            data = r.read()
            return r.status, (json.loads(data) if data else {})
    except urllib.error.HTTPError as e:
        text = e.read().decode(errors="replace")
        if e.code == 401 and not MODE["individual"]:
            MODE["individual"] = True  # maybe an Individual key: try once as one
            return call(method, path, body, ok)
        if e.code == 401:
            fail("Apple refused the key (401). Check ASC_KEY_ID (the Key ID of this key), ASC_ISSUER_ID (the Issuer ID above the keys "
                 "table) and that ASC_KEY_P8 is that same key's .p8. Also accept any new agreement in developer.apple.com > Account "
                 "and App Store Connect > Business.")
        if e.code == 403:
            fail(f"The key is not allowed to do this (403). Make a Team key with Access: Admin. Apple said: {text[:300]}")
        if e.code in ok:
            return e.code, {}
        fail(f"{method} {path} failed ({e.code}): {text[:500]}")


def check():
    bundle = os.environ["BUNDLE_ID"]
    _, ids = call("GET", f"/bundleIds?filter[identifier]={bundle}&limit=5")
    match = [b for b in ids.get("data", []) if b["attributes"]["identifier"] == bundle]
    if not match:
        print(f"Bundle ID {bundle} is not registered: registering it.")
        _, made = call("POST", "/bundleIds", {"data": {"type": "bundleIds", "attributes": {"identifier": bundle, "name": "Dandoona English", "platform": "IOS"}}})
        match = [made["data"]]
    _, apps = call("GET", f"/apps?filter[bundleId]={bundle}&limit=5")
    if not apps.get("data"):
        fail(f"No app with Bundle ID {bundle} in App Store Connect. Create it: appstoreconnect.apple.com > Apps > + > New App "
             f"(platform iOS, Bundle ID {bundle}), then run again.")
    if MODE["individual"]:
        print("::warning::This is an Individual key. Signing may need a Team key with Admin access (App Store Connect > Users and Access > Integrations > Team Keys).")
    print(f"Key works. Bundle ID registered. App in App Store Connect: {apps['data'][0]['attributes']['name']}")
    return match[0]["id"]


def create():
    out = os.environ["OUT_DIR"]
    os.makedirs(out, exist_ok=True)
    bundle_ref = check()
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Dandoona CI"), x509.NameAttribute(NameOID.EMAIL_ADDRESS, "ci@example.com")]))
           .sign(key, hashes.SHA256()))
    csr_pem = csr.public_bytes(serialization.Encoding.PEM).decode()
    status, cert = call("POST", "/certificates", {"data": {"type": "certificates", "attributes": {"certificateType": "DISTRIBUTION", "csrContent": csr_pem}}}, ok=(201,))
    cert_id = cert["data"]["id"]
    der = base64.b64decode(cert["data"]["attributes"]["certificateContent"])
    certificate = x509.load_der_x509_certificate(der)
    state = {"certificate": cert_id}
    json.dump(state, open(os.path.join(out, "state.json"), "w"))  # saved now, so cleanup can revoke it even if later steps fail
    # the legacy p12 encryption (3DES, SHA1 MAC): the macOS keychain does not import the newer AES one
    legacy = (serialization.PrivateFormat.PKCS12.encryption_builder().kdf_rounds(50000)
              .key_cert_algorithm(pkcs12.PBES.PBESv1SHA1And3KeyTripleDESCBC).hmac_hash(hashes.SHA1())
              .build(os.environ["P12_PASSWORD"].encode()))
    p12 = pkcs12.serialize_key_and_certificates(b"Dandoona CI", key, certificate, None, legacy)
    open(os.path.join(out, "signing.p12"), "wb").write(p12)
    name = f"Dandoona CI {os.environ.get('RUN_NAME', int(time.time()))}"
    _, prof = call("POST", "/profiles", {"data": {"type": "profiles", "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
                                                  "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_ref}},
                                                                    "certificates": {"data": [{"type": "certificates", "id": cert_id}]}}}})
    state["profile"] = prof["data"]["id"]
    state["profileName"] = name
    state["profileUuid"] = prof["data"]["attributes"]["uuid"]
    json.dump(state, open(os.path.join(out, "state.json"), "w"))
    open(os.path.join(out, "profile.mobileprovision"), "wb").write(base64.b64decode(prof["data"]["attributes"]["profileContent"]))
    print(f"Made a distribution certificate and the App Store profile '{name}'.")
    gh = os.environ.get("GITHUB_OUTPUT")
    if gh:
        with open(gh, "a") as f:
            f.write(f"profile_name={name}\nprofile_uuid={state['profileUuid']}\n")


def cleanup():
    path = os.path.join(os.environ["OUT_DIR"], "state.json")
    if not os.path.exists(path):
        print("Nothing to clean up.")
        return
    state = json.load(open(path))
    if "profile" in state:
        call("DELETE", f"/profiles/{state['profile']}", ok=(204, 404))
    if "certificate" in state:
        call("DELETE", f"/certificates/{state['certificate']}", ok=(204, 404))
    print("Removed this run's profile and certificate.")


if __name__ == "__main__":
    {"check": check, "create": create, "cleanup": cleanup}[sys.argv[1]]()
