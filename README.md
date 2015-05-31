# What is this?

Miniosa is a **min**imalistic **iOS a**udio library providing easy, low latency access to input and output audio buffers. And that's pretty much it. The intended audience is people who want to do real time audio processing.

# How do I use it?

Add ``MNAudioEngine.h`` and ``MNAudioEngine.m`` to your project. Check out the demo app and the ``MNAudioEngine.h`` header for further information about the API.

# Good to know
 * Minioasa audio buffers contain floating point samples with values between -1 and 1 (inclusive).
 * A frame is a set of samples taken at the same point in time. For example, a stereo frame consists of two values (one per channel) and a mono frame is just a single value. 
 * Audio buffers contain interleaved samples, i.e frames are stored sequentially. An interleaved stereo buffer looks like this:
 
	 ```
 	t0 left, t0 right, t1 left, t1 right ...
	 ```
 
 * The buffer callbacks are invoked from a high priority audio thread. Don't perform time consuming tasks in these callbacks, or audible dropouts will occur. 