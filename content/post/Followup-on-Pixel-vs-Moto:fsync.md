+++
date = "2017-02-20T10:54:24+02:00"
subtitle = ""
title = "Google safety vs risky Moto performance"
bigimg = ""
draft = false

+++
I need to follow up on my [blog post](/post/Moto-Z-has-10x-less-lag-than-pixel/) re Pixel lagging more than Moto Z. Sorry about the click-baity title of the previous blog, but that was a way to get noticed and get some help.

I am really thankful for the [small percentage of] thoughtful feedback I received.

There were some helpful commenters on hackernews and twitter that helped explain what's going on.

1. Turns out Motorola uses the F2FS + `nobarrier` mount option to speed up writes to NAND. **`nobarrier` does not turn fsync is a no-op.**
It schedules writes to NAND without waiting for completion. As a result, apps appear to complete 
writes immediately and multiple consecutive writes can become parallel writes. This is awesome for performance and possibly for NAND longevity.

2. All Moto phones since 2014 release of Moto X (developed under Google ownership) use 'this one neat trick'.

3. fsync() is used to request durability and ordering from the file system. `nobarrier` means that in an event one has to recover from a crash, one can't be sure any IO was committed or that it was committed in right order.

4. F2FS is a log-structured file system that usually appends on writes (eg no overwrites). During normal operation, it's more likely than [overwriting] ext4 to recover to a consistent state after a crash (possibly losing most recent writes). However it switches to inline-overwrites as it becomes full. I think that implies read-modify-write: corruption of older data.

5. F2FS has no notion of sequence of write operations, so if sequential fsync() operations become parallel, NAND writes complete in wrong order and there is a crash...This will cause nearly-impossible to catch corruption in SQLite and other apps that rely on a certain write ordering.

6. Apparently Moto did a lot of testing (under Google ownership!) and made a calculated risk here. F2FS authors were initially skeptical, but added support for `nobarrier` based on Moto testing feedback.

7. Linux used default to 'async' behavior on hard drives by leaving the write-cache on. OSX does this by default. More details in this [blog post](http://blog.httrack.com/blog/2013/11/15/everything-you-always-wanted-to-know-about-fsync/). It might be reasonable for consumer devices to default to what databases used to default to. Phones have an advantage here as they are more likely to have an office-backup on some cloud service.

I think it's cool to see this sort of experimentation happening in quest for market share. It would be nice if power users had the option to flip on `nobarrier` F2FS on every phone.

I would love to see what sort of testing data Moto has on this.