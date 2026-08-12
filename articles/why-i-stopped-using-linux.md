# *Why I stopped using Linux?*
Written by FlyWithMe (a SimpleX Chat user) — Updated August 13, 2026

This article will be dedicated to talking about Systemd/GNU/Linux and the reasons that made me abandon it, at the end I will be talking about alternatives for those who want to do the same.

My critical analysis on the topic is purely technical, not subjective, but many people may not care about such things. The purpose of this article is not to prove anything, and links will be provided as examples only. The article aims to make the reader distrust what they know (or what they think they know) and instigate in-depth research.

This article is not intended to be the most complete and in-depth, and as the title suggests, it is based on what I consider relevant to me.

## Security concerns

I am digital security enjoyer, and software that is not secure cannot be enjoyable to me.

I completely abandoned Windows 10 years ago for security reasons, and about 2 years ago I completely abandoned using Linux for the same reasons. I've been using Linux for over 13 years, and Linux has never been about security, but it took me a long time to realize that.

> “If you don’t treat security like a religious fanatic, you are going to be hurt like you can’t imagine. And Linus never took seriously the religious fanaticism around security,”
- Dave Aitel, a former National Security Agency research scientist and founder of Immunity, a Florida-based security company.

(Btw, It is ironic that the NSA, the largest surveillance and monitoring agency in the world, is responsible for the most relevant security advancement in the Linux world (SELinux). This is very, very funny.)

> "The people who care most about this stuff are completely crazy. They are very black and white,”
- Linus Torvalds.

> “Security in itself is useless. . . . The upside is always somewhere else. The security is never the thing that you really care about.”
- Linus Torvalds.

> “I personally consider security bugs to be just ‘normal bugs.’ I don’t cover them up, but I also don’t have any reason what-so-ever to think it’s a good idea to track them and announce them as something special.”
- Linus Torvalds.

Torvalds has engaged in an occasionally profane standoff with experts on the subject. One group he has dismissed as “masturbating monkeys.”
http://article.gmane.org/gmane.linux.kernel/706950

In blasting the security features produced by another group, he said in a public post, “Please just kill yourself now. The world would be a better place.”

Everything above can be read here:
https://www.washingtonpost.com/sf/business/2015/11/05/net-of-insecurity-the-kernel-of-the-argument

It doesn't take much to finally understand that Linux has been insecure since its creation, and the developers (especially its creator) don't take security seriously.

> "What about "security-focused" Linux operating systems like Qubes OS? Linux can be very secure"
- Ignorant Linux fanboy.

Well, they're not as safe as you think:
https://handbook.uhden.dev/articles/qubes-os.html

The Linux operating system that I consider to be the most secure by default is Secureblue. The development team takes security very seriously, and they don't mind trading usability for security. Let's see what they say about Linux:
 
> Who is secureblue for?

> secureblue is for those whose first priority is using Linux, and second priority is security. secureblue does not claim to be the most secure option available on the desktop. We are limited in that regard by the current state of desktop Linux standardization, tooling, and upstream security development. What we aim for instead is to be the most secure option for those who already intend to use Linux. As such, if security is your first priority, secureblue may not be the best option for you.
https://secureblue.dev/

I have many years of experience with Linux, especially in hardening Linux systems, and I have never seen hardening as strong as that applied in Secureblue (which is based on immutable Fedora). The fact, as was said, is that Linux is extremely limited when it comes to security.

Linux is not secure by default, additional hardening is extremely necessary, and with the exception of Secureblue and perhaps ChromeOS, no Linux distribution can be considered secure by default. But even an extremely hardened Linux distro cannot escape the fact, Linux will always be insecure, because the insecurity is in the kernel code.
https://madaidans-insecurities.github.io/linux.html

The Linux kernel and Systemd/GNU/Linux distros have a huge and frightening attack surface. In 2025 the Linux kernel reached the impressive number of 40 million lines of code, and Linux distros (such as Debian) already surpass the 1 billion lines of code mark.
https://commandlinux.com/statistics/linux-kernel-contributors-lines-of-code-statistics/
https://micronews.debian.org/2023/1686455026.html/
https://sources.debian.org/stats/

For comparison, the entire OpenBSD operating system has ~36 million lines of code (the kernel has 8 mLoC), which is less than just the Linux kernel. But there are operating systems that are much smaller in codebase, such as RedoxOS, SculptOS, TockOS, and LionOS. These operating systems consequently have a much smaller attack surface than Linux.

Here is a hardening guide for Linux, it is not complete and is out of date, but it is good to serve as a basis for readers to do in-depth research later.
https://madaidans-insecurities.github.io/guides/linux-hardening.html


## Complexity

I have used all types of Linux operating systems, some of them being: Debian, Ubuntu, Fedora, openSUSE, Arch, Manjaro, CachyOS, Artix, Gentoo, QubesOS, Exherbo, Secureblue, Alpine and even Linux from Scratch. No one can say "skill issue" to me, because I know what I'm talking about.

No matter which distribution it is, they all have something in common, complexity. And I'm not talking about desktop environments as this is irrelevant to someone who knows how to use the terminal or tilling window managers, I'm referring to the configuration of the system as a whole.

The firewall, sudo, systemd, networking, kernel parameters, daemons, and /etc and /usr files in general are all unnecessarily complex, and this is only noticeable when an experienced Linux user migrates to another operating system such as FreeBSD, OpenBSD and NetBSD.

Systemd is the biggest piece garbage in the Linux world when it comes to complexity (1.3 million lines of code btw), something worthy of being proprietary software from Microsoft (although Red Hat is the Microsoft of the open source world xD).

Achieving minimally pleasant hardening on Linux is extremely difficult and is not viable for the vast majority of users. I've already wasted weeks hardening on Arch Linux only to end up with shit because of systemd. I've already wasted 2 months hardening on Gentoo and 6 months hardening on Linux from Scratch, it's simply not something realistic to maintain by just one person and can drive you crazy.

I mentioned Arch and Gentoo because I consider them to be the most hardening-friendly Linux distributions, whether due to the incredible documentation on the Arch Wiki or Gentoo's incredible control and customization.

I don't need to elaborate much on this topic. Linux is complex, that's all.


## Instability

Stability is something necessary and indispensable in my life, but unfortunately I don't find it in Linux. It doesn't matter if it's Debian stable or Ubuntu LTS, the promise of stability is not something to be trusted.

Many people think that stability is just about life cycle, how long software will be properly maintained without having to update it for a new release. But this is wrong, stability is about a system remaining working exactly as it was in the beginning even after many updates, installed packages and changed system configurations.

I've had more stability using Arch Linux than Ubuntu LTS and Debian stable. But no matter which Linux distribution you use, it is inevitable that the system will break at one time or another. It's amazing how a Linux system can break so easily and unexpectedly just because you installed too many packages or updated the system.

It seems to me that almost all Linux users think this is normal, it has become something so everyday and common that people have accepted Linux's instability as a feature. It got to a point where I could only achieve pleasant stability on Linux with extremely minimalist distros and configurations to the point where I didn't even have security (no MAC, Wayland, sandboxing, firewall, kernel parameters, boot config or any hardening at all).

It's understandable that one of the biggest struggles of enterprise Linux distributions is stability. Red Hat (RHEL), Microsoft (Azure Linux) and Canonical (Ubuntu) invest a lot to deliver the most stable environment possible, and yet they lag behind other non-Linux operating systems. Android and ChromeOS are probably the only stable Linux operating systems.

Linux has always been unstable and will probably always be unstable.


## Centralized decentralization
###### (Or would it be decentralized centralization?)

Linux's biggest advantage has been completely thrown away, and it has become a huge disadvantage. What was once GNU/Linux became Systemd/GNU/Linux/IBM.

Linux is just the kernel, and this provides enormous potential for decentralization and motivates the community to create all kinds of software. But what's the point if everything is GNU and systemd? The Linux world has reached a point where the only difference between distributions are the packages installed by default and sometimes the package manager.

I've seen a lot of stupid skids say "install Kali Linux, use Kali Linux, it's amazing and blah blah blah...", but what's the fucking difference between Kali and Debian? It's just that Kali is bloated and has more packages installed, but it's literally the same garbage. Even in distros like Ubuntu and Fedora the only considerable change besides the installed packages is the package manager itself.

IBM seems to have dominated the entire Linux ecosystem with Red Hat: Fedora, systemd, SELinux, libvirt, Xorg, Flatpak, + 100 other strong/main contributions to other Linux software like GNOME, KDE, d-bus and Wayland (even the freedesktop.org organization was created by a Red Hat employee). IBM currently has strong dominance and/or authority over the entire Linux ecosystem and even over the kernel development.

The only different alternative are non-GNU distros such as Alpine, Void and Chimera (also Gentoo). However, in the end they all end up being very similar, as they use musl/BusyBox and the packages you can install are the same as those available for all other GNU/systemd distributions. If you can completely get rid of systemd, GNU coreutils, glibc and d-bus, that's already a lot.

Now comes my second review. The Linux kernel and userland being developed separately is horrible. Each software in the Linux world has different developers with different philosophies, mindsets and goals. This is a mess and only brings instability, complexity, insecurity and heartbreak.

Systemd/GNU/Linux/IBM tries to be 2 things at the same time, centralized and decentralized, but in the end it can't be either completely, and that's ridiculous.


## License

As I already talked about in my other article: http://cypherpunk-handbook.i2p/articles/openbsd.html#obsd-14

> Linux has spent years pulled between community goals and large corporate interests, especially from companies such as IBM that want Linux shaped for enterprise platforms. That pressure damages the Unix philosophy.

If Linux were distributed under a permissive license like BSD and MIT this would not happen, as companies would not make an effort to change the mainstream Linux project to suit their wishes. Not only IBM, but also Microsoft, Google, Intel and many other companies have already influenced decisions in the development of Linux, influences that are not always (or almost never) positive, or are even ideological:

https://linuxreviews.org/Intel_Is_Pushing_For_1984-Style_Revision_Of_Words_Allowed_In_Linux_Kernel_Development_And_Documentation

No matter what GNU fanboys say about permissive licenses, it is a fact that they guarantee the purity of the mainstream project, while restrictive licenses like GPL motivate technical or ideological fights between different corporations to influence the development of the software.

There is no freedom restricting freedom. Selective freedom is not freedom, and therefore restrictive licenses like GPL deliver a false sense of freedom, deceiving the user into believing that the software is free when in fact the project is driven by the will of large corporations.

Unfortunately, not even the most used permissive licenses such as BSD, MIT and Apache are in fact completely free, but they are much better than restrictive licenses.


## Politics

In the Linux world, what prevails is not the technical and rational argument, but rather subjective opinions and political ideologies. Decisions that are useless for the actual functionality of a project are common when dealing with Linux software development. The basis for making decisions in Linux are the emotions you are feeling at the moment.

(and Red Hat strikes again)

https://linuxiac.com/the-curious-case-of-xlibre-server/
https://linuxiac.com/xlibre-xserver-project-plans-revival-of-x11/

As shown in the previous topic about the influence of large companies on the development of the Linux kernel, the creator of Linux himself was influenced and applied ideological and completely useless changes into the project:

**Linux Torvalds has merged inclusive-terminology rules into the Linux kernel git tree**
https://linuxreviews.org/Linus_Torvalds_Has_Merged_Inclusive_Terminology_Rules_Into_The_Linux_Kernel_Git_Tree

If you want to contribute to the Linux ecosystem, don't worry about giving technical and grounded arguments to build the project's development, just follow your ideological and political heart:

**detect-fash: A utility to detect problematic software and configurations**
https://github.com/systemd/systemd/pull/39285

You also don't need to argue rationally about why you reject a good project that brought life to dead software, just say whatever bullshit comes to mind and refuse technological advancement because the project developer disagrees with your political opinions:

Aeryn OS rejects XLibre: "Hell no. Its author is spreading conspiracy theories..."
https://web.archive.org/web/20250705031120/https://github.com/orgs/AerynOS/discussions/50#discussioncomment-13550829

Chimera Linux rejects XLibre: Political reasons
https://gts.chimera-linux.org/@chimera/statuses/01JYYNAB4GFQ8Q5JZZ92TRM4WF

https://gts.q66.moe/@q66/statuses/01KCGZ33XYS5XBN1N95JGP6197

Alpine Linux rejects XLibre: Political reasons
https://irclogs.alpinelinux.org/%23alpine-devel-2025-06.log

https://gitlab.alpinelinux.org/alpine/aports/-/merge_requests/86092

https://social.treehouse.systems/@ariadne/114768921289154195

https://ariadne.space/2025/07/07/two-weeks-of-wayback.html

That's it, I know a few thousand more cases on the subject to show, but it's not necessary. Linux is not a serious environment for serious people, and it should not demand to be taken seriously.


## Community

Since 2019, the Linux community in general has been in decline, getting worse every day. Everything has become political and ideological, purely technical groups almost no longer exist.

Technical merit no longer exists, if you are against the ideology of a certain group, you will be muted or banned from their groups that are supposed to be about Linux, or you will even be threatened with death.

They can speak about their political ideologies and mental delusions freely as long as it is in accordance with the administrators' thinking (for them it is permitted), but when someone responds with disagreement they are brutally attacked. All this in a community that is supposed to be about software.

The many Linux communities seem to have been infected with a scary mental disease, people act crazy and are mentally unstable most of the time. It is not uncommon to see senseless psychological outbursts in Discord groups, Matrix, social media and internet forums.

It became unbearable for me (and I believe for thousands of other people too) to be part of the Linux community. I miss the Arch Linux community 8 years ago, I considered it the most technical and capable community on the internet, everything was technical, specialized and knowledge was abundant.

There is no perfect community, because people are not perfect and there will never be someone who pleases you 100% in everything, diversity of ideas is normal. The problem is that there is no more freedom of speech among the Linux community. There are many dictators who hide behind the facade of "free and open source software" or "digital freedom" bullshit, but if they could, they would literally kill you or send you to the gulag.

You are free, but only as long as you agree with them.

There can be no real technological advancement in a community like this, nor is it possible to obtain useful knowledge in these environments. And, how I hate codes of conduct... The greater the code of conduct, the greater the intellectual decline of a community.

Dictators and mentally unstable people everywhere, that's how I see the Linux community these days.


## Superior alternatives

### BSDs

Obviously the best alternative for Linux users is BSD operating systems. I will not recommend Windows or macOS xD. BSDs are independent and complete operating systems, that is, the kernel and userland are developed together by the same developers. They are typically more stable, simple, secure, minimalist and reliable than Linux distributions.

To understand more about the differences between BSD operating systems:
https://www.unixdigest.com/articles/the-main-differences-between-openbsd-freebsd-netbsd-and-dragonflybsd.html

https://wikipedia.org/wiki/Comparison_of_BSD_operating_systems

#### OpenBSD

Currently OpenBSD is the operating system I use daily. OpenBSD is very secure by default, simple and minimalist, politics-free, and has perhaps the most technical community of all.

> The OpenBSD project produces a FREE, multi-platform 4.4BSD-based UNIX-like operating system. Our efforts emphasize portability, standardization, correctness, proactive security and integrated cryptography. As an example of the effect OpenBSD has, the popular OpenSSH software comes from OpenBSD.
https://www.openbsd.org/

> Be as politics-free as possible; solutions should be decided on the basis of technical merit.
https://www.openbsd.org/goals.html

It is an operating system focused on security, I recommend reading my other article about it:
http://cypherpunk-handbook.i2p/articles/openbsd.html

The repository is small, it has around 10k packages and there is no Wine or Linuxlator.

#### FreeBSD

This was the first operating system I used after leaving Linux, it is the most recommended BSD for users who do not want to lose the "usability" they had on Linux, as FreeBSD has Linuxlator (compatibility layer for running Linux binaries), Wine and even Steam. FreeBSD has the fourth largest repository of all operating systems, with approximately 33k packages, behind only NixOS, AUR and Debian.

> FreeBSD is an operating system for a variety of plataforms which focuses on features, speed and stability. It is derived from BSD, the version of UNIX developed at the University of California, Berkeley. It is developed and maintained by a largue community
https://www.freebsd.org/about

Unfortunately FreeBSD has the same problem as Linux (albeit on a smaller scale) regarding the community, but at least the technical level remains high and this does not affect the development of the operating system (at least yet).

Read and strictly follow the handbook during installation:
https://docs.freebsd.org/en/books/handbook/


#### NetBSD

This is a true operating system for hackers, and it is probably the most portable operating system ever (much more than any Linux OS). It will certainly run on your hardware, even if it's a Nintendo64 (I'm not kidding).

> NetBSD is a free, fast, secure, and highly portable Unix-like Open Source operating system. It is available for a wide range of platforms, from large-scale servers and powerful desktop systems to handheld and embedded devices.
https://netbsd.org/

pkgsrc (the NetBSD Packages Collection repository) currently contains over 26,000 packages. NetBSD also has Wine and Linuxlator.


### Good Linux operating systems?

Although this article is about my dissatisfaction with Linux and also an encouragement for other people to stop using it, I understand that not everyone will want to do this for many other reasons that go beyond those mentioned in this article. So I'm going to recommend some Linux operating systems that might still be worth using, although none of them escape everything I talked about in the article.

#### Gentoo

Very complex and slow (compilation), but it gives total freedom and control to the user, so with some time and reading the documentation it is possible to achieve a relatively secure, independent and extremely minimalist Gentoo.

My recommendation: do hardening and configure a full musl + BusyBox system.

#### Guix (+ Nonguix)

GNU everywhere but at least no Systemd, and it is a declarative system. The community isn't that bad, it's perhaps the "less worse" Linux community.

Can be very stable and minimalist. Unfortunately proprietary blobs are necessary for proper security on x86, so use Nonguix.

#### GrapheneOS

> GrapheneOS is a privacy and security focused mobile OS with Android appcompatibility developed as a non-profit open source project. It's focused on the research and development of privacy and security technology including substantial improvements to sandboxing, exploit mitigations and the permission model.
https://grapheneos.org/

It's not a Linux distribution, but it is a Linux operating system, and it's the only Linux I use. I really like GrapheneOS, but it is not free from Google's decisions regarding Android and Google Pixel.




> An idiot admires complexity, a genius admires simplicity. For an idiot, anything more complicated is the more he will admire it, if you make something so cluster fucked he can't understand it, he's gonna think you're a god. Cause you made it so complicated nobody can understand it.
- Terry A. Davis, TempleOS creator and God's loneliest soldier.
