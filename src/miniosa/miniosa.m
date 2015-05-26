#include <assert.h>

#include "miniosa.h"
#include "coreaudio_io.h"

mnError mnStart(mnAudioInputCallback inputCallback,
                mnAudioOutputCallback outputCallback,
                void* callbackContext,
                mnOptions* options)
{
    return mnInitialize(inputCallback, outputCallback, callbackContext, options);
}

mnError mnStop()
{
    return mnDeinitialize();
}

mnError mnSuspend()
{
    mnSuspendAudio();
    
    
    return MN_NO_ERROR; //TODO: proper error code
}

mnError mnResume()
{
    return mnResumeAudio();
    
    return MN_NO_ERROR; //TODO: proper error code
}
