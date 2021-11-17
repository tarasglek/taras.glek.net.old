+++
date = "2016-11-12T12:16:32-08:00"
title = "Laggy phones and misleading benchmarks"
draft = false

+++

TLDR: You can predict degree of unresponsiveness of a phone via random-write-4k benchmarks. I wish review websites would fill phones to 80-90% prior to running the benchmark, especially on smaller-capacity phones where users are more likely to run out of space.

<p><strong>SQLite vs Phone NAND</strong></p>

<p>I’ve long held a theory that Android lag is almost directly determined by slowness induced by SQLite transactions. This weekend, while researching phones for a family member, I found some supporting evidence.</p>

<p>I was employed to analyze Firefox performance at Mozilla. Most of the time I focused on IO performance as my niche. This was relatively easy because desktop OSes (especially Windows with XPerf and Linux being open source) are very open to developers. Unfortunately as a hobbyist I have less chances to figure out why my phones are slow. None of my phones have root, let alone an unlocked bootloader (eg no ability to recompile the kernel with IO tracing functionality).</p>

<p>In the past I verified that all of my phones that got super-laggy were exhibiting single-digit-per-second write-random-4k benchmarks. However until now I couldn’t point at SQLite is the main driver of IO on Android.</p>

<p>To trace IOs on Android one has to recompile the kernel or at-least have root to run something like <a href="https://github.com/nowsecure/fsmon">fsmon</a> to observe high level IO.
 I was able to run fsmon on my rooted Android TV box and overserve that most of the IO occurred in SQLite databases.</p>

<p><em>For some reason Android does not default to using WAL journaling mode for SQLite which would make it use 2x-less IOPS.</em></p>

<p><strong>Nested Journalling Magnifies Cost of SQLite IO</strong></p>

<p>In addition to fsmon stats, I found a great <a href="http://esos.hanyang.ac.kr/files/publication/conferences/international/On%20the%20IO%20characteristics%20of%20the%20SQLite%20Transactions.pdf">paper</a> on how SQLite accounts for 90% of Android IO and how it amplifies every write transaction by ~4x by the time it hits the underlying storage (eg 1commit ~= 4 fsyncs). It also shows how a 100 bytes of SQL data translates into 64KB of block writes.</p>

<p>Basic premise of the paper is that SQLite journaling is amplified by ext4 filesystem journal resulting in extreme badness. One is tempted to assume that it is further amplified by the GC on the EMMC NAND controller :)</p>

<p>I actually think the paper is overly optimistic in focusing on length of time taken by a single SQLite transaction. In reality one is likely to wait on more than one transaction due to having to update multiple databases or poorly written code (common problem with ORMs).</p>

<p>Combine above data with the fact that Phone NAND is the only component that gets consistently slower as your phone ages. Memory cells wear out and NAND garbage collector slows as the phone fills up to 80-90% of storage capacity. Note one can briefly regain better system performance by doing a full reset.</p>

<p><strong>Bad Android IO Patterns</strong></p>

<p>SQLite is the default way of persisting structured data on Android. Android <a href="https://developer.android.com/training/basics/data-storage/databases.html">documentation</a> seems to default to showing how to do SQLite IO on main thread (<a href="http://hvasconcelos.github.io/articles/Offloading-work-from-the-UI-Thread">explanation</a>). This means that Android apps are often waiting on reading and writing to NAND instead of responding to user input.</p>

<p>Even if most of the IO happens on a background thread, the mechanics of IO dispatch and low queue depths in consumer-grade environments mean that even if there is a large off-main-thread/background IO infront small IO on main thread, small IO. will take a long time to complete. If one is lucky and only runs apps without main thread IO on Android,there will still be the problem of waiting for long IOs.</p>

<p><strong>Conclusion</strong></p>

<p>A core principle of performance engineering is that a system is only as fast as the slowest bottleneck. In this particular case the bottleneck is hit very frequently, so seemingly users don’t get to benefit from fancy CPUs much.</p>

<p>Interestingly, unlike with CPU perf, there is no correlation between random writes and price of the phone. Random 4k writes on modern flagship hw are very slow compared to any other metric. IPhone 7 struggles to do over <a href="http://www.anandtech.com/show/10685/the-iphone-7-and-iphone-7-plus-review/4">2MB/s</a>. Google Pixel struggles to get above <a href="http://www.anandtech.com/show/9972/the-google-pixel-c-review/3">2MB/s</a> too.</p>

<p>This means that irrespective of the graphics cores, CPU cores, your phone is going to suck as much as random write perf… This sort of barely-acceptable performance will quickly turn into a “My phone is too laggy, I need to upgrade” as NAND perf deteriorates.</p>

<p>Instead of burying random-write-4k performance (or not doing that test at all), reviews should expose that front-and-center. Ideally they would also fill up the phone to 80% to match a realistic usecase.</p>

<p>There is atleast one phone vendor who gets it. Motorola G4 is <a href="http://www.anandtech.com/show/10514/the-motorola-moto-g4-and-g4-plus-review/3">7x better</a> than the flagships. Surprisingly my $60 ZTE ZMax Pro phone is also 2-3x better than the flagships.</p>

<p>If you know people who run hardware review websites, please ask them to focus on random-write-4k performance as predictor of jank/lag/frustration.</p>

<p><a href="https://www.reddit.com/r/Android/comments/5e3rbu/laggy_phones_and_misleading_benchmarks/">Comments/Reddit</a></p>

<p><a href="https://news.ycombinator.com/item?id=13001753">Comments/HackerNews</a></p>