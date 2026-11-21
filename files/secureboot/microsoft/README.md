# Microsoft's Secure Boot certificates

Public certificates, enrolled next to this computer's own keys when the
firmware is in Setup Mode (`lib/secureboot.sh`, `sb_enroll_own`), so that
Windows, firmware updates and graphics cards' firmware (option ROMs) keep
starting. Without them a PC can fail to show anything at power-on.

From Microsoft's repository https://github.com/microsoft/secureboot_objects
(`PreSignedObjects/KEK/Certificates`, `PreSignedObjects/DB/Certificates`,
commit 3d762aecbaecd12402efd21ba89c8c7bd40da4bd), renamed without spaces:

| File | Certificate | SHA-256 of the file |
|---|---|---|
| `KEK/microsoft-kek-ca-2011.der` | Microsoft Corporation KEK CA 2011 | `a1117f516a32cefcba3f2d1ace10a87972fd6bbe8fe0d0b996e09e65d802a503` |
| `KEK/microsoft-kek-2k-ca-2023.der` | Microsoft Corporation KEK 2K CA 2023 | `3cd3f0309edae228767a976dd40d9f4affc4fbd5218f2e8cc3c9dd97e8ac6f9d` |
| `db/windows-production-pca-2011.der` | Microsoft Windows Production PCA 2011 | `e8e95f0733a55e8bad7be0a1413ee23c51fcea64b3c8fa6a786935fddcc71961` |
| `db/microsoft-uefi-ca-2011.der` | Microsoft Corporation UEFI CA 2011 | `48e99b991f57fc52f76149599bff0a58c47154229b9f8d603ac40d3500248507` |
| `db/windows-uefi-ca-2023.der` | Windows UEFI CA 2023 | `076f1fea90ac29155ebf77c17682f75f1fdd1be196da302dc8461e350a9ae330` |
| `db/microsoft-uefi-ca-2023.der` | Microsoft UEFI CA 2023 | `f6124e34125bee3fe6d79a574eaa7b91c0e7bd9d929c1a321178efd611dad901` |
| `db/microsoft-option-rom-uefi-ca-2023.der` | Microsoft Option ROM UEFI CA 2023 | `e5be3e64c6e66a281457ecdece0d6d0787577aad2a3a0144262c10c14ba8d8f1` |

The 2011 certificates expire in 2026; firmware does not check expiry dates,
and what was signed with them keeps starting, so both generations are
enrolled (as Microsoft does on Windows PCs during the transition).
