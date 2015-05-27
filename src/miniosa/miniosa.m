#include <assert.h>

#include "miniosa.h"
#include "mem.h"
#include "instance.h"

static mnInstance* s_instance = NULL;

mnError mnStart(mnAudioInputCallback inputCallback,
                mnAudioOutputCallback outputCallback,
                void* callbackContext,
                mnOptions* options)
{
    if (s_instance) {
        return MN_ALREADY_INITIALIZED;
    }
    
    s_instance = MN_MALLOC(sizeof(mnInstance), "mnInstance singleton");
    
    return mnInstance_initialize(s_instance, inputCallback, outputCallback, callbackContext, options);
}

mnError mnStop()
{
    if (!s_instance) {
        return MN_NOT_INITIALIZED;
    }
    
    mnInstance_deinitialize(s_instance);
    MN_FREE(s_instance);
    s_instance = NULL;
    
    return MN_NO_ERROR;
}

mnError mnSuspend()
{
    if (!s_instance) {
        return MN_NOT_INITIALIZED;
    }
    
    return mnInstance_suspend(s_instance);
}

mnError mnResume()
{
    if (!s_instance) {
        return MN_NOT_INITIALIZED;
    }
    
    return mnInstance_resume(s_instance);
}
