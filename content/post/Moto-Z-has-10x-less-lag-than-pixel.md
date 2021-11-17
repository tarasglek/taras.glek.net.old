+++
date = "2016-12-11T12:17:23-08:00"
title = "Why Google Pixel lags 10x more than Moto Z"
draft = false

+++
![Alt text](/images/moto-z-vs-pixel/moto-z-pixel-latency.png "Optional title")

<p>In my previous post I made an argument that a modern phone is only as fast as the slowest component: ability of NAND to handle <a href="/post/Laggy-phones-and-misleading-benchmarks/">4k writes</a>.
I decided to compare two Android flagships on the opposite ends of
random-write-4k benchmark spectrum: <a href="http://amzn.to/2hkMchI">Moto Z</a> vs <a href="http://amzn.to/2grbBJB">Google Pixel</a>.</p>

<p>I wrote a little fio <a href="https://github.com/tarasglek/fio/blob/master/termux/fill.py">benchmark driver</a> to fill all available device storage with random 4k writes, print perf stats along the way. Idea is to run the benchmark on <code>/data/</code>
partition, then fill all available space by writing to <code>/storage/emulated/0</code>, then do another round of testing on <code>/data</code>.</p>

<p>The chart above has p50 (50% IOs complete under X), p90 and p99 numbers for both devices. Moto Z median value is around <code>0.5ms</code>, Pixel is 7x that at <code>3.3ms</code>. Difference widens for p90.</p>

<p>On mobile phones 16.67ms is a magic number. That’s the amount of time one has to update screen at buttery-smooth 60FPS.
Optimistically, one can roughly translate each data-persistence operation on Android into at-least 2 sequential random writes (best-case WAL SQLite mode).
So if an app is saving a single piece of data, expect 6.6ms to be eaten up
 by IO on Pixel and when your device is busy, expect that number to rise quickly.</p>

<p>Note this is best-case performance for these devices, I expect performance to degrade as they age. Expect Pixel to drop frames or stutter as it ages. Pixel performs relatively
poorly in this test.</p>

<p><strong>How Motorola Smoked Google by ~10x at Storage Perf</strong></p>

<p>I spent a few days poking around the filesystems while developing my benchmark experiment.
Motorola (division of Lenovo) has bravely gone above and beyond stock Android to reduce storage lag. They got Moto-Z to performing close to high-end laptop SSDs.</p>

<p>How did Motorola do this? Answers were hiding in <code>/proc/mounts</code> file.</p>

<ul>
<li><code>/storage/emulated/0</code>: Google added a <a href="https://source.android.com/devices/storage/">weird</a> permission model for the common storage pool on Android. In a fit of either lazyness or rushing to
meet some PM deadlines for features no users asked for: they wrote a passthrough <code>fuse</code> filesystem to enforce cross-app-file-sharing. This means that on the Pixel every user IO gets a round-trip back into user-space before hitting the NAND. <a href="https://github.com/libfuse/libfuse">Fuse</a> burns more CPU and slows down IO by up to 30%. I love fuse for things like sshfs, but this is a terrible application of it.
Motorola thought a little harder and replaced the nasty fuse hack with <code>esdfs</code>(<a href="https://github.com/vadimtk/moto-x-kernel/tree/master/fs/esdfs">fork</a> of <a href="http://wrapfs.filesystems.org/">wrapfs</a>).</li>
<li><code>/data</code>: Pixel uses the traditional <code>ext4</code> Linux filesystem. Moto-Z opted for <code>f2fs</code>.
f2fs is a new filesystem developed by Samsung. It’s amazing, read the <a href="https://www.usenix.org/conference/fast15/technical-sessions/presentation/lee">paper &amp; watch preso</a>. They drove development of the filesystem specifically by Twitter/FB/etc workloads captured from the phone.
It does many neat things, but the thing it does best is avoid fsync write-amplification. F2FS flags fsyncs via block metadata instead of doing a full checkpoint.
This means fsync requires 50%-less write operations than ext4 (interestingly competing filesystems like BTRFS have even higher fsync write amplification than ext4). I think the tradeoff is slightly slower recovery times. <em>f2fs nets Moto-Z a 2x speed-up and 2x increase in NAND lifespan</em>. Expect Moto-Z to age much better than Pixel.</li>
<li><code>nobarrier</code>: Moto-Z has a very interesting mount option soup for mounting f2fs: <code>rw,seclabel,nosuid,nodev,noatime,nodiratime,background_gc=on,discard,user_xattr,inline_xattr,acl,inline_data,nobarrier,extent_cache,active_logs=6</code>.
Just for kicks I took a USB hard-drive, formatted it with f2fs and applied same mount options. Suddenly the <em>hard drive</em> was 2x faster than the Pixel, WTF?</li>
</ul>

<p>The key option is <code>nobarrier</code>.
This effectively makes fsync() a no-op and explains most of the difference in performance. See <a href="http://xfs.org/index.php/XFS_FAQ">XFS FAQ</a> for the best description of <em>nobarrier</em> feature. This is where most of the performance difference comes from.
Moto-Z is either awesome and implemented a RAM-cache solution for cellphones, or they are betting on excellent crash-recovery abilities of f2fs or they are really brave on behalf of users. Even if they didn’t implement battery-backed-RAM-cache for their NAND and that f2fs isn’t overly horrible at recovering from crashes this is probably still the right choice. As a user, I’m much happier to have a long-lasting phone that might forget a couple of seconds of data than a device that has to be trashed after a year of use.</p>

<p>If anyone has root on Pixel and Moto-Z, would be interesting to see if underlying block devices perform differently. I suspect they are very similar and that Motorola differentiates entirely in software.</p>

<p><strong>Conclusion</strong></p>

<p>Android OEMs like Motorola/Samsung (f2fs authors) are improving Android performance. <a href="http://amzn.to/2hkMchI">Moto Z</a> and a few other recent Androids have drastically reduced storage lag. Next time you are shopping, try to avoid buying devices that will slow down to point of being unusable as NAND wears out (ala Nexus 7, Nexus 6). I doubt anyone would spot the difference between a brand new Pixel and Moto-Z. However after a year of use, the difference should be stark.</p>

<p>Phone reviewers should be more vigilant and shame poorly-implemented devices. I won’t be recommending the Pixel to any family members.</p>

<p>I’m not recommending people buy Moto Z. WIFI/cell reception seems worse on Z than Pixel. Camera is worse too.</p>

<p><a href="https://news.ycombinator.com/item?id=13155894">Comments/HackerNews</a></p>

<p><a href="https://www.reddit.com/r/Android/comments/5htkmk/why_google_pixel_lags_10x_more_than_moto_z/">Comments/Reddit</a></p>

<p><strong>Updates</strong></p>

<ol>
<li><p>I’m confusing UI state transitions with UI animations. Android animation framework does not run on main thread. Disregard 16.6ms section</p></li>

<li><p>In a follow-up twitter discussion, Android engineers made a solid case that this is likely a hack. If Motorola made nobarrier a no-op in hw, it wouldn’t be needed in sw (eg <a href="http://oss.sgi.com/archives/xfs/2015-12/msg00281.html">this email</a>). It’s unclear how <code>nobarrier</code> was deemed safe. One could theorize that Motorola spent time QAing failure scenarios.</p></li>

<li><p>I’m still hoping that an Android vendor will implement battery-backed-RAM-cache to solve the write-4k-bottleneck. Moto-Z can be considered a <em>risky</em> prototype of what storage performance should be like. Will be interesting to see if my prediction of Pixel aging worse than Z come true. I doubt write-4k is a bottleneck in any android workload on the Moto-Z.</p></li>
</ol>