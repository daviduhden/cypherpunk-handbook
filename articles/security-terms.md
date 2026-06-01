# Terms and explanations of security in operating systems.
Written by FlyWithMe (a SimpleX Chat user) — Updated May 31, 2026

This document is dedicated to giving a brief but precise explanation of several terms related to security in operating systems, which can confuse even the most experienced people. This document is not intended to explain all the terms used and documented in all operating systems, nor specific programs, but only universal concepts.

------------------------------------------------------------------------

### 1. MAC — _Mandatory Access Control_

A system-enforced policy that restricts access based on fixed labels/clearances assigned to subjects and objects.

- Example: SELinux enforcing file type labels to prevent processes from reading /etc/shadow.

### 2. RBAC — _Role-Based Access Control_

Grants permissions to roles instead of users; users acquire permissions by being assigned roles.

- Example: Linux sudoers grouping admin users into an "admin" role.

### 3. DAC — _Discretionary Access Control_

Resource owners set access permissions (owner/group/others).

- Example: UNIX file permissions (chmod/chown).

### 4. ABAC — _Attribute-Based Access Control_

Access decisions based on attributes of the subject, object, action, and environment (policies evaluate attributes).

- Example: An access policy allowing access only if user.department == "HR" and request.time < 18:00.

### 5. RB-RBAC — _Rule-Based Role-Based Access Control_

RBAC extended with rules/policies that dynamically enable or constrain roles. 

- Example: Temporarily elevating a role when a specific condition (on-call) is met.

### 6. ACL — _Access Control List_

A list attached to an object that specifies which users or system processes are granted access and what operations they can perform.

- Example: Windows NTFS file ACL entries granting Read/Write to a user.

### 7. ACE — _Access Control Entry_

A single entry in an ACL specifying a principal and allowed/denied permissions.

- Example: An ACE in an NTFS ACL that denies Delete to a specific user.

### 8. POLP — _Principle of Least Privilege_

Design principle: give processes/users only the privileges they need.

- Example: Running a web server without root; only granting CAP_NET_BIND_SERVICE.

### 9. NX (NX bit) — _No‑eXecute bit_

No-eXecute bit — CPU-supported page attribute marking memory pages non-executable to prevent code execution from data pages.

- Example: Marking the stack non-executable to block stack-smashing payloads.

### 10. DEP — _Data Execution Prevention_

OS/CPU feature using NX to prevent execution of code on data pages.

- Example: Windows DEP blocking execution of injected shellcode in heap.

### 11. ASLR — _Address Space Layout Randomization_

Randomizes memory region addresses (stack, heap, libraries, executables) to make exploitation harder.

- Example: Linux/Windows randomizing libc and stack base addresses at process start.

### 12. KASLR — _Kernel Address Space Layout Randomization_

ASLR applied to kernel memory layout to protect against kernel-level exploits.

- Example: Randomizing kernel base address on modern Linux kernels.

### 13. PIE — _Position Independent Executable_

An executable built so it can be loaded at any address (enables ASLR for the main binary).

- Example: Modern distributions compile executables with -fPIE and link with -pie.

### 14. IPsec — _Internet Protocol Security_

Suite of protocols for authenticating and encrypting IP packets (AH, ESP, IKE).

- Example: Site-to-site VPN using IPsec ESP for encrypted tunnels.

### 15. SELinux — _Security‑Enhanced Linux_

A label-based MAC implementation for Linux providing fine-grained access controls enforced by the kernel.

- Example: Enforcing separate domains for httpd so it can't access user home dirs.

### 16. AppArmor — _Application Armor_

Profile-based MAC for Linux that restricts programs to permitted file/network/syscall actions via profiles. 

- Example: An AppArmor profile limiting Firefox to its config and download dirs.

### 17. LSM — _Linux Security Modules_

Kernel framework providing hooks for multiple security modules (SELinux, AppArmor, Landlock).

- Example: /sys/kernel/security/lsm showing active modules.

### 18. PAM — _Pluggable Authentication Modules_

Modular authentication framework for Unix-like systems to configure authentication, account, session, and password policies. 

- Example: pam_pwquality enforcing password complexity.

### 19. TPM — _Trusted Platform Module_

Hardware chip providing secure storage for keys, platform attestation, and sealed storage. 

- Example: Storing disk encryption keys and performing measured boot attestation.

### 20. TCB — _Trusted Computing Base_

The set of hardware, firmware, and software that enforces the system’s security policy; must be trusted.

- Example: kernel + firmware + secure boot chain forming a TCB for an OS.

### 21. UEFI Secure Boot — _Unified Extensible Firmware Interface Secure Boot_

Firmware feature that verifies signed bootloader/kernel before execution to prevent boot-time tampering.

- Example: PCs rejecting unsigned bootloaders unless Secure Boot disabled.

### 22. SMEP — _Supervisor Mode Execution Protection_

CPU feature preventing the kernel (supervisor mode) from executing code in user-mode pages.

- Example: Blocks kernel execution of user-space injected code on Intel CPUs.

### 23. SMAP — _Supervisor Mode Access Prevention_

CPU feature preventing the kernel from accessing user-space memory unless explicitly enabled.

- Example: Kernel must enable access when copying data from user space; otherwise accesses fault.

### 24. SEH — _Structured Exception Handling_ (Windows)

Windows mechanism for exception handling; historically targeted by exploitation (SEH overwrite).

- Example: SEH chain protecting exception handlers; mitigations include SafeSEH, SEHOP.

### 25. MIC — _Mandatory Integrity Control_ (Windows)

Windows integrity levels enforcing that lower-integrity processes cannot write to higher-integrity objects.

- Example: Internet Explorer running at Low integrity cannot write to files at Medium integrity.

### 26. SUID — _Set User ID_ (on execution)

UNIX file permission bit that makes a program execute with the file owner's privileges (commonly root).

- Example: /usr/bin/passwd having SUID root to modify /etc/shadow.

### 27. CAP — _Linux Capabilities_

 Fine-grained privileges that split root powers into discrete capabilities (CAP_NET_BIND_SERVICE, CAP_SYS_ADMIN, etc.).

- Example: setcap 'cap_net_bind_service=+ep' /usr/bin/nginx to allow binding to port 80 without root.

### 28. Sandbox — Application Sandbox

A security technique that builds on isolation and adds explicit, least‑privilege restrictions, syscall/IO/permission filters and monitoring to run untrusted code safely; intent is to limit capabilities and detect/contain misuse.

- Example:

**Browser renderer sandbox:** per-tab process + seccomp/MAC policies + capability drops to block filesystem/network access.
**seccomp-bpf sandbox:** Linux process allowed only a small syscall whitelist.
**pledge (OpenBSD):** process declares a small syscall whitelist (pledges); violating it kills the process.
**unveil (OpenBSD):** syscall that restricts a process’s filesystem view to explicitly revealed paths and permissions.

### 29. Isolation

A security/architectural boundary that prevents components from affecting each other by separating resources, privileges, and address spaces; its goal is containment and trust separation, not necessarily active restriction of behavior.

- Example:

**Process isolation:** separate virtual address spaces so one process cannot read another’s memory (typical on Linux/Windows).

**VM/hypervisor isolation:** guests run separate kernels so a guest compromise usually cannot affect the host.

**Hardware isolation:** IOMMU prevents device DMA to arbitrary memory; TPM stores measurements and keys.

### 30. FIPS — _Federal Information Processing Standard_

U.S. government standards (e.g., FIPS 140-2/3) specifying security requirements for cryptographic modules and practices.

- Example: Using a FIPS-validated OpenSSL module for compliant cryptography.

### 31. Stack canary

A small random value placed between local variables and the return address on the stack; checked on function return to detect stack-buffer-overflow overwrites.

- Example: GCC’s -fstack-protector adds canaries to vulnerable functions (e.g., strcpy).

### 32. SSP — _Stack Smashing Protector_

Compiler-based feature that inserts stack canaries and checks to prevent return-address overwrites. 

- Example: GCC/Clang enabling SSP for hardened builds.

### 33. CFI — _Control‑Flow Integrity_

Ensures program execution follows a valid control-flow graph (prevents arbitrary jumps/gadgets).

- Example: LLVM’s -fsanitize=cfi or Microsoft's CFG (Control Flow Guard).

### 34. Shadow stack

A protected, separate stack that records return addresses; the CPU/OS verifies actual return addresses against the shadow copy to prevent ROP attacks.

- Example: Intel CET's shadow stack implementation.

### 35. PAC — _Pointer Authentication Code_

CPU feature that cryptographically signs (authenticates) pointers to detect tampering; signature checked before use.

- Example: ARMv8.3-A PAC used on iOS devices to protect return addresses and function pointers.

### 36. CET — _Control‑flow Enforcement Technology_

Intel CPU feature combining shadow stacks and indirect-branch tracking to prevent ROP/JOP and control-flow hijacks.

- Example: CET-enabled Windows builds using shadow stacks.

### 37. Intel SGX — _Intel Software Guard Extensions_

CPU enclaves providing isolated, attested memory regions for executing sensitive code and data protected from the OS/hypervisor.

- Example: An application storing crypto keys inside an SGX enclave.

### 38. ARM TrustZone Technology

CPU/SoC security extension splitting system into Secure and Non‑Secure worlds for isolated execution of trusted code.

- Example: Secure bootloader and key storage running in TrustZone on Android devices.

### 39. Secure Enclave

Hardware-backed secure coprocessor providing isolated key storage and cryptographic operations (Apple’s implementation).

- Example: iPhone storing fingerprint/FaceID templates and disk encryption keys in Secure Enclave.

### 40. TXT — _Intel Trusted Execution_ Technology

Platform feature for measured/isolated launch of trusted environments using TPM for attestation.

- Example: Measured launch of a hypervisor with TPM quotes.

### 41. IOMMU — _Input–Output Memory Management Unit_

Hardware that isolates and remaps DMA from devices, preventing device-initiated DMA attacks and enabling passthrough.

- Example: VT-d/IOMMU used to safely assign a PCIe device to a VM.

### 42. VT-d — _Intel Virtualization Technology for Directed I/O_

Intel’s IOMMU implementation providing DMA isolation and interrupt remapping for VMs.

- Example: Passing a GPU through to a KVM guest using VT-d.

### 43. AMD‑Vi — _AMD I/O Virtualization_ (IOMMU)

AMD's equivalent of VT-d providing device DMA isolation.

- Example: PCI device passthrough to VMs on AMD hosts.

### 44. VBS — _Virtualization‑based Security_

Technique using a small hypervisor to isolate sensitive OS components (e.g., credential stores) from the main OS.

- Example: Windows using VBS to isolate LSASS or Credential Guard.

### 45. HVCI — _Hypervisor‑protected Code Integrity_

Uses VBS to validate kernel code integrity in an isolated environment, blocking unsigned or tampered kernel code.

- Example: Windows Hypervisor-Enforced Code Integrity enabled with VBS.

### 46. Hypervisor introspection

Monitoring guest OS state from the hypervisor for security (detection/forensics) without inside-agent presence.

- Example: A cloud hypervisor scanning guest memory for rootkits.

### 47. seccomp — _Secure Computing Mode_ (seccomp‑bpf)

Linux kernel facility to restrict a process’s allowed syscalls using BPF filters; used to implement lightweight sandboxes.

- Example: Chromium using seccomp-bpf to limit renderer syscalls.

### 48. cgroups — _Control Groups_

Kernel feature to group processes and limit/measure resource usage (CPU, memory, I/O), used for containment and DoS mitigation.

- Example: Docker using cgroups to cap container memory and CPU.

### 49. namespaces — _Linux Namespaces_

Kernel isolation primitives that give processes separate views of system resources (pid, mount, net, ipc, uts, user), used for containers.

- Example: Creating an isolated network namespace for a container.

### 50. LUKS — _Linux Unified Key Setup_

Standard on-disk format for full-disk encryption on Linux, storing keyslots and metadata.

- Example: Encrypting root partition with LUKS and using a passphrase at boot.

### 51. dm‑crypt — _Device-mapper crypt target_

Kernel subsystem providing disk encryption backend (commonly used with LUKS).

- Example: dm-crypt encrypting an ext4 filesystem on a block device.

### 52. eBPF sandboxing

Using extended BPF programs to enforce security policies, filter events, or sandbox behaviors in kernel space safely.

- Example: eBPF hooking network syscalls to implement a firewall or syscall filter.

### 53. W^X — _Write XOR Execute policy_

Memory protection policy ensuring pages are writable OR executable, never both, to prevent writable code injection.

- Example: Hardened kernels enforcing W^X for JITs to use controlled APIs to toggle permissions.

### 54. RASP — _Runtime Application Self‑Protection_

In-app runtime defenses that detect and mitigate attacks (e.g., injection, tampering) from inside the application.

- Example: A web app embedding a runtime monitor that blocks suspicious inputs or modifies behavior on attack.

### 55. MACsec — _Media Access Control Security_

Layer 2 protocol providing MAC-layer encryption and integrity between switches/links.

- Example: Securing Ethernet links between data-center switches with MACsec.

### 56. FDE — _Full Disk Encryption_

Encrypting entire storage devices to protect data at rest; keys typically stored in TPM or provided at boot.

- Example: BitLocker (Windows), SoftRaid (OpenBSD) or LUKS (Linux) encrypting the system drive.

### 57. MFA — _Multi‑Factor Authentication_

Authentication requiring two or more independent credentials (something you know, have, or are).

- Example: Password + TOTP code from an authenticator app.

### 58. 2FA — _Two‑Factor Authentication_

Subset of MFA using exactly two factors.

- Example: Password + SMS OTP (not recommended compared to app-based TOTP).

### 59. SSO — _Single Sign‑On_

Centralized authentication allowing one login to access multiple services via tokens.

- Example: OAuth/OIDC SSO to access multiple corporate apps using the same identity provider.

### 60. OAuth — OAuth Authorization Framework

Token-based protocol that delegates access without sharing credentials; commonly used for API authorization.

- Example: An app obtaining an access token to call a user’s Google Drive.

### 61. SAML — _Security Assertion Markup Language_

XML-based standard for exchanging authentication/authorization assertions between identity providers and service providers.

- Example: Enterprise SSO using SAML to authenticate to web apps.

### 62. X.509 Public Key Certificate

Standard format for public key certificates used in TLS and PKI to bind public keys to identities.

- Example: HTTPS sites presenting an X.509 certificate signed by a CA.

### 63. PKCS#11 — _Public-Key Cryptography Standards #11_

API standard for cryptographic token interfaces (HSMs, smartcards) to use keys without exposing them.

- Example: An application using PKCS#11 to perform signing with an HSM-held key.

### 64. HSM — _Hardware Security Module_

Dedicated hardware that securely generates, stores, and uses cryptographic keys with tamper resistance.

- Example: A cloud HSM storing CA private keys and performing TLS signing.

### 65. Key wrapping

Encrypting (wrapping) encryption keys with a Key Encryption Key (KEK) for safe storage/transport.

- Example: Wrapping a disk encryption master key with a TPM-held wrapping key.

### 66. Measured boot

Recording measurements (hashes) of firmware/boot components into TPM to attest boot integrity; used to detect tampering.

- Example: Platform stores bootloader/kernel hashes in TPM PCRs for remote attestation.

### 67. Container

OS-level virtualization unit that packages processes with isolated views (namespaces) and resource limits (cgroups); shares the host kernel but provides a lightweight, repeatable runtime environment.

- Example: Docker/OCI containers use PID, mount, net, user namespaces + cgroups to isolate processes and limit CPU/memory; a containerized web app runs in its own namespace but shares the host kernel.

### 68. Memory safety

Memory safety is the state of being protected from various software bugs and security vulnerabilities when dealing with memory access. Memory-safe languages prevent common memory errors (buffer overflows, use‑after‑free, null/dangling pointer access, uninitialized reads) by enforcing rules or runtime checks that ensure safe allocation, access, and deallocation of memory; approaches include garbage collection (Java, C#, Go, Python), reference counting, and compile-time ownership/borrowing checked by the compiler (Rust), yielding fewer security bugs and crashes while trading off some control or runtime overhead depending on the strategy.

- Examples: Rust (ownership + zero-cost safety), Go/Java/C# (Garbage Collector), Swift/Kotlin/Python/JavaScript (memory-managed).

### 68. Garbage collection

A runtime system automatically finds and reclaims memory that the program can no longer reach (preventing leaks and many pointer errors) by tracing or reference counting; it simplifies programming but adds runtime overhead and possible pauses

- Examples: Java, Go, C#, Python, JavaScript.

### 69. Ownership/borrowing

A compile-time system (used by Rust) where each value has a single owner, scope-based deallocation, and explicit borrowing rules (& for shared read, &mut for exclusive write) that prevent use-after-free and data races with no GC overhead.

- Example: Rust.

### 70. RELRO — _Relocation Read-Only_

Is an ELF hardening option that makes relocation-related sections (notably the GOT) read-only after startup to prevent GOT-overwrite attacks; Partial RELRO (-Wl,-z,relro) leaves .got.plt writable and allows lazy binding, while Full RELRO (-Wl,-z,relro,-z,now) forces eager symbol resolution and marks the entire GOT read-only.

- Example: compile with full RELRO to mitigate GOT overwrites — gcc -Wl,-z,relro,-z,now -o myprog myprog.c — (partial RELRO: gcc -Wl,-z,relro -o myprog myprog.c).

### 71. KARL — _Kernel Address Randomized Link_

Relinks kernel object files in a random order at each boot so function locations differ every boot (mitigates reuse/ROP attacks).

- Example: OpenBSD’s KARL rebuilds a new kernel from object files after each boot so addresses change across reboots.

### 72. SROP — _Sigreturn-Oriented Programming_

An exploit technique that forges a signal frame and invokes sigreturn to set registers and execute syscalls (a compact alternative to ROP).

- Example: push a crafted sigcontext on the stack, return into a “syscall; ret” gadget with RAX set to rt_sigreturn, then have rt_sigreturn restore registers to invoke execve("/bin/sh").

### 73. Library order randomization

Randomizes the order (or load addresses) of shared libraries to add ASLR entropy and make gadget/tooling guesses harder.

- Example: randomizing the order libc and other .so files are loaded so an attacker cannot rely on a fixed library base for ROP gadgets.

### 74. Kernel relinking at boot (relinking/relink-on-boot)

Rebuilds or reorders kernel objects into a new kernel binary at boot time so the kernel’s internal layout is unique per boot (increasing entropy beyond simple base-address KASLR).

- Example: build a new kernel image from shuffled .o files at each boot and install it for the next boot, as used in KARL workflows.

### 74. NOP — _No Operation_

A single CPU instruction that does nothing but advance execution; used in exploits as a NOP-sled (a long sequence of NOPs) so a faulted jump into the sled "slides" into the attack payload.

- Example: a buffer overflow payload begins with many 0x90 bytes (x86 NOP) followed by shellcode so any return address into the sled will reach the shellcode.

### 75. ROP — _Return-Oriented Programming_

An exploitation technique that chains short instruction sequences already present in memory ("gadgets") ending in ret to perform arbitrary computation without injecting new code (bypasses NX/DEP).

- Example: build a ROP chain using gadgets like "pop rdi; ret" and "pop rsi; ret" from libc to set registers and then call mprotect or system("/bin/sh").

### 76. malloc

Is a library routine (part of the memory allocator) that gives a program a contiguous block of uninitialized bytes from the heap at runtime; the allocator manages free/used blocks, requests memory from the OS (e.g., sbrk/mmap), and returns a pointer or NULL on failure. Implementations vary and handle fragmentation, alignment, and multithreading differently.

- Examples: lmalloc, ptmalloc, jemalloc, tcmalloc, mimalloc, musl malloc, PartitionAlloc, rpmalloc, scudo, hardened_malloc.

### 77. Memory allocator

Is the part of a runtime/library that manages dynamic heap memory: it satisfies requests for variable-size blocks (malloc/calloc/realloc/new), tracks which blocks are free or in use, requests/releases memory from the OS (sbrk/mmap/VirtualAlloc), minimizes fragmentation, enforces alignment, and handles concurrency and performance trade-offs.

- Example: dlmalloc, ptmalloc, jemalloc, tcmalloc, mimalloc, musl malloc, PartitionAlloc, rpmalloc, scudo, hardened_malloc.

### 78. Capability-based security

Is an authorization model where unforgeable "capabilities" (tokens or references) both name a resource and carry the exact rights allowed; possession of a capability is sufficient to access the resource, so systems grant and delegate fine-grained privileges by passing or restricting capabilities instead of relying on global identity-based checks (ACLs).

- Examples:
- (1) A file descriptor returned by open() is a capability letting that process read/write the file.
- (2) macaroons (HMAC-based tokens) used to grant limited, delegable API access in distributed systems.
- (3) Capsicum-like OS sandboxes or capability-based OSes (e.g., early capability hardware systems or research OSes) where processes receive only the specific capabilities they need, reducing ambient authority and preventing confused-deputy bugs.

### 79. MPU — _Memory Protection Unit_

A simple hardware block—common in microcontrollers—that divides physical memory into configurable regions and enforces per-region access permissions (read/write/execute) and privilege levels; unlike an MMU it does not provide virtual memory or address translation, only protection.

- Examples: 
- (1) ARM Cortex‑M MPUs let firmware mark RAM as execute‑never or read‑only to stop code execution from stack or protect configuration data.
- (2) an MPU in an RTOS isolates each task’s stack and data so a buggy task can’t corrupt others.
- (3) automotive controllers use system/ core/ peripheral MPUs to prevent DMA or peripherals from accessing critical memory ranges.

### 80. MMU — _Memory Management Unit_

Is hardware that translates virtual/logical addresses to physical addresses, enforces per-page permissions (read/write/execute, user vs supervisor), and enables virtual memory, process isolation, paging, and swapping.

- Examples: x86/ARM MMUs that let operating systems give each process its own virtual address space and implement demand paging and copy‑on‑write.

### 81. RTOS — _Real‑Time Operating System_

Is an OS designed to provide deterministic, low-latency scheduling and predictable timing for time‑critical tasks (often with priority‑based preemptive schedulers and minimal jitter).

- Examples: FreeRTOS used on microcontrollers for motor control with hard deadlines, and VxWorks in avionics where meeting strict timing guarantees is required.

### 82. Privilege escalation

Is when an attacker (or a program) gains higher access rights than originally allowed—either by moving laterally to another account with similar rights (horizontal) or by elevating a low‑privilege account to admin/root (vertical); it’s typically achieved by exploiting vulnerabilities, misconfigurations, stolen credentials, or flawed software logic.

- Examples: (1) a web app vuln lets an attacker execute commands as root (vertical), (2) stealing another user’s session cookie to access their files (horizontal), (3) abusing a misconfigured SUID binary on Linux to spawn a root shell.

### 83. Attack surface

Is the total set of points (digital, physical, and human) where an attacker can attempt to enter or extract data from a system; reducing it limits opportunities for compromise.

- Example: exposed internet services and open ports on servers, unused APIs and forgotten cloud instances (digital); unlocked server rooms or USB ports (physical); and phishing‑prone employees or weak passwords (human/social).

### 84. MTE — _Memory Tagging Extension_

Hardware feature (ARM MTE) that associates small tags with memory blocks and pointers to detect spatial/temporal memory errors (out‑of‑bounds, use‑after‑free) at runtime with low overhead.

- Example: enabling MTE on firmware catches a stale pointer dereference before it corrupts control data.

### 85. Exploit Mitigations

Techniques (hardware and software) that raise the difficulty of exploitation.

Example: ASLR, NX/DEP, stack canaries, RELRO, Control‑Flow Integrity (CFI) and sandboxing; combined they reduce successful exploit reliability even when vulnerabilities exist.

### 86. Code signing

Cryptographic signing of binaries/firmware so receivers can verify origin and integrity before execution.

- Example: digitally signed OS updates or drivers that the bootloader or package manager verifies to prevent tampered releases.

### 87. Chain of trust

Boot‑time and update model where each stage cryptographically verifies the next (root of trust → bootloader → kernel → userland), ensuring only authorized code runs.

- Example: secure/UEFI boot verifies bootloader signature, which verifies the kernel signature.

## 88. Supply chain

All people, processes, tools, code, and hardware involved in producing/deploying a product (development tools, libraries, build systems, vendors).

- Example: third‑party libraries and CI/CD pipelines are part of the software supply chain.

### 89. Supply-chain attack

An adversary compromises an upstream element (maintainer, build system, vendor, CI/CD, or signing keys) to distribute malicious code or components to many downstream victims.

- Example: SolarWinds (compromised build pipeline) and trojanized signed installers (3CX/MOVEit incidents).

### 90. Malware

Is any program designed to damage, disrupt, steal from, or gain unauthorized access to computers, networks or data.

- Example: viruses that infect programs (e.g., CIH), ransomware that encrypts files (e.g., WannaCry), and spyware that steals credentials (e.g., Pegasus).

### 91. Virus

Attaches to legitimate programs or files and runs when the host does; replicates by infecting other files.

- Example: the Melissa macro virus that spread via infected documents.

### 92. Worm

Self-replicating malware that spreads across networks without needing a host file or user action.

- Example: Stuxnet (network-spreading component) and Conficker.

### 93. Trojan horse

 Malware disguised as useful software; runs when the user installs it and typically installs backdoors or other payloads.

- Example: Emotet delivering other malware.

### 94. Ransomware

Encrypts or blocks access to data/systems and demands payment for recovery.

- Example: WannaCry, Ryuk.

### 95. Spyware

Secretly monitors user activity and exfiltrates data (credentials, browsing, microphone/camera).

- Example: Pegasus.

### 96. Adware

Displays unwanted ads, tracks browsing for monetization; often intrusive but sometimes bundled with installers.

- Example: Fireball

### 97. Rootkit

Hides itself and other malware by operating at kernel/firmware level, giving persistent privileged control and evading detection.

- Example: Sony BMG rootkit.

### 98. Keylogger

Records keystrokes to capture passwords and messages; can be hardware or software.

- Example: commercial/fraudulent keyloggers used to steal banking credentials.

### 99. Botnet

Network of infected machines remotely controlled to send spam, DDoS, or mine crypto; infection often via trojans/worms.

- Example: Mirai.

### 100. Fileless malware

Runs in memory or abuses legitimate system tools (PowerShell, WMI) so nothing is written to disk, making detection harder.

- Example: Astaroth-style campaigns.

### 101. Polymorphic/metamorphic malware

Changes its code/signature each infection to evade signature-based detection; often used in sophisticated campaigns.

- Example: Storm Worm, VirLock, CryptoLocker (polymorphic); advanced metamorphic families used in targeted campaigns.

### 102. Wiper

Intentionally destroys or irreversibly deletes data rather than holding it for ransom.

- Example: NotPetya (acted as a wiper).

### 103. Crypto‑miner (cryptojacker)

Silent installation of mining software to use host CPU/GPU for cryptocurrency mining, slowing systems and raising power use.

- Example: Coinhive-style in‑browser miners and hidden Monero miners deployed by botnets (cryptominers run silently to mine crypto).

### 104. Mobile malware

Targets smartphones/tablets (malicious apps, SMS fraud, spyware).

- Example: Triada on Android.

### 105. Backdoor

Provides covert remote access to a system for later use (often installed by trojans); commonly part of multi-stage attacks. Can be software or hardware.

- Example: Intel ME, PlugX, various Remote Access Trojans that give persistent covert access and control.

### 106. Downloader / Dropper

Small program whose sole job is to fetch and install additional malware (used to stage larger infections).

- Example: Emotet commonly acted as a dropper/downloader that fetches and installs other payloads.

### 107. Exploit kit

Toolkit that probes and exploits browser/plug-in vulnerabilities (often via malvertising) to deliver payloads without user interaction.

- Example: Angler Exploit Kit and Blackhole EK used to probe browser/plug‑in flaws and silently deliver payloads.

### 108. Grayware/Potentially Unwanted Application (PUA)

Annoying or privacy-invasive software (toolbars, bundlers) that’s not overtly destructive but degrades security.