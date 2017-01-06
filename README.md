slickr
======

A collection of python and bash scripts to collect and analyze frame rendering performance in Android apps.

## requirements

* [python](https://www.python.org/)
* [matplotlib](http://matplotlib.org/) - only needed for `plot.py`

## setup

### on device

**Make sure to enable the "In adb shell dumpsys gfxinfo" option for "Profile GPU rendering" inside _"Developer options"_ in your settings app!**

_You may need to kill and restart your app for the logging to work!_

### on computer

If you can't execute the scripts, you may need to mark them as executable.

```bash
$ chmod +x *.sh *.py
```

should do the trick on Unix-like operating systems, or cygwin.

## examples

Scroll for 8 seconds and save the GPU profiling information for the current screen into a file.

```bash
$ ./slickr.sh -s ecxs3342d -p com.android.settings > profile.txt
```

Scroll for 8 seconds and display the average frame delay (in milliseconds).

```bash
$ ./slickr.sh -p com.android.launcher -H | ./avg.py
```

Scroll for 8 seconds and plot the recorded data and other metrics.

```bash
$ ./slickr.sh | ./plot.py
```

Compare the frame delay histograms and demand curves of two (or more) saved profiles.

```bash
$ ./compare.py profile1.txt profile2.txt
```

## api

```bash
$ slickr.sh -p <package> -c <iterations> -s <serial> -H
-p       package  Package to get
-s       serial to test, if one device connected, please skip
-c       interaction to handle
-H       horizontal scrolling enabled
```

* `package` is the Java package name for the Android application. For example, for the [Tumblr app](https://play.google.com/store/apps/details?id=com.tumblr), it is `com.tumblr`. It can be gleaned from the play store url for an application.

    If an app has multiple activities open, `profile.py` will choose the activity with `visibility=0` (the currently visibile activity). On devices below [Lollipop](https://developer.android.com/about/versions/lollipop.html), all profile data is exported.

* `iterations` is the number of 2 second iterations to run (since 128 frames, the default buffer size, is a duration of about 2 seconds at 60 frames per second). Default is `4`.

* `distance` is the scroll distance in pixels. It defaults to 3x the display density (at the bucket the device belongs to).

[`framestats` in Android Marshmallow (6.0)](http://developer.android.com/preview/testing/performance.html#timing-info) is automatically enabled as long as a package name is provided. It provides detailed information about the draw stage of the rendering pipeline.

## understanding the plots

![tumblr app profile](/../example/com.tumblr.png?raw=true)

The Android M `framestats` data [is a series of raw timestamps](http://developer.android.com/preview/testing/performance.html#fs-data-format). These are then converted into time deltas according to the Android Developer guidelines. The [`gfxinfo` data](https://io2015codelabs.appspot.com/codelabs/android-performance-profile-gpu-rendering#5) is also plotted if available, though there is some overlap.

| component  | `gfxinfo` | `framestats` timestamps                              | notes                              |
| ---------- | --------- | ---------------------------------------------------- | ---------------------------------- |
| start      | &darr;    | `INTENDED_VSYNC` &rarr; `HANDLE_INPUT_START`         | time spent by system               |
| input      | &darr;    | `HANDLE_INPUT_START` &rarr; `ANIMATION_START`        | time spent handling input events   |
| animations | &darr;    | `ANIMATION_START` &rarr; `PERFORM_TRAVERSALS_START` | time spent evaluating animators    |
| traversals | &darr;    | `PERFORM_TRAVERSALS_START` &rarr; `DRAW_START`       | time spent on layout and measure   |
| draw       | draw      | `DRAW_START` &rarr; `SYNC_START`                     | time spent on `View.draw()`        |
| sync       | prepare   | `SYNC_START` &rarr; `ISSUE_DRAW_COMMANDS_START`      | time spent transfering data to gpu |
| &darr;     | execute   |                                                      | time spent executing display lists |
| gpu        | process   | `ISSUE_DRAW_COMMANDS_START` &rarr; `FRAME_COMPLETED` | time spent waiting on gpu          |

The green line represents the 16.67 ms threshold needed to achieve a [smooth 60 frames per second](https://www.youtube.com/watch?v=CaMTIgxCSqU).

### duration curve

The duration curve rearranges the profiling data by sorting it from slowest to fastest frame. This is based off [load duration curves](https://en.wikipedia.org/wiki/Load_duration_curve) in power engineering and illustrates how many frames went over the 16 ms threshold needed for 60 FPS and how many milliseconds they went over.
