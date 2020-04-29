#!/usr/bin/env python3

# See: https://github.com/fernet/spec/blob/master/Spec.md

import fileinput
import re
import os
import sys

import secrets
from base64 import urlsafe_b64encode as b64e, urlsafe_b64decode as b64d

from cryptography.fernet import Fernet
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

backend = default_backend()

def _derive_key(password: bytes, salt: bytes, iterations: int) -> bytes:
    """Derive a secret key from a given password and salt"""
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(), length=32, salt=salt,
        iterations=iterations, backend=backend)
    return b64e(kdf.derive(password))

def value_encrypt(message: bytes, password: str, iterations: int) -> bytes:
    salt = os.urandom(16)
    key = _derive_key(password.encode(), salt, iterations)
    print("Key is: %s" % (key,))
    return b64e(
        b'%b%b%b' % (
            salt,
            iterations.to_bytes(4, 'big'),
            b64d(Fernet(key).encrypt(message)),
        )
    )

def value_decrypt(token: bytes, password: str) -> bytes:
    decoded = b64d(token)
    salt, iter, token = decoded[:16], decoded[16:20], b64e(decoded[20:])
    iterations = int.from_bytes(iter, 'big')
    key = _derive_key(password.encode(), salt, iterations)
    return Fernet(key).decrypt(token)

def replace_and_encrypt(re_match, password, iterations):
    value_plain = re_match.group(1)
    value_enc = value_encrypt(bytes(value_plain, 'utf-8'), password, iterations)
    value_dec = value_decrypt(value_enc, password)
    if bytearray(value_dec) == bytearray(value_plain, 'utf-8'):
        return ("%s" % (value_enc.decode('utf-8'),))
    return ("ERROR")

sPassword   = "password"
cIterations = 100_000
sFilename   = "./loeffler_digitaler_nachlass_p2.md"

with fileinput.FileInput(sFilename, inplace=False, backup='.bak') as file:
    for line in file:
        print(re.sub(r'\%(.*)\%', lambda m: replace_and_encrypt(m, sPassword, cIterations), line))
