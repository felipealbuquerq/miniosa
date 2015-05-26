#include <assert.h>
#include <string.h>
#include <stdio.h>
#include "mem.h"

#ifdef DEBUG

#define  MN_MAX_NUM_DEBUG_ALLOCATION_RECORDS 1024

typedef struct mnAllocationRecord
{
    void* ptr;
    size_t size;
    const char* tag;
} mnAllocationRecord;

static mnAllocationRecord allocationRecords[ MN_MAX_NUM_DEBUG_ALLOCATION_RECORDS];

static int clearRecords = 1;

static size_t numLiveBytes = 0;

#endif

void* mnMalloc(size_t size, const char* tag)
{
#ifdef DEBUG
    if (clearRecords)
    {
        memset(allocationRecords, 0,  MN_MAX_NUM_DEBUG_ALLOCATION_RECORDS * sizeof(mnAllocationRecord));
        clearRecords = 0;
    }
    
    mnAllocationRecord* record = NULL;
    
    for (int i = 0; i <  MN_MAX_NUM_DEBUG_ALLOCATION_RECORDS; i++)
    {
        if (allocationRecords[i].ptr == 0)
        {
            record = &allocationRecords[i];
            break;
        }
    }
    
    if (!record)
    {
        assert(0 && "no free allocation records!");
        return NULL;
    }
    
    record->ptr = malloc(size);
    record->size = size;
    record->tag = tag;
    numLiveBytes += size;
    
    printf("allocated pointer %ld bytes at %p (%s), live bytes %ld\n",
           record->size, record->ptr, tag, numLiveBytes);
    
    return record->ptr;
#else
    return malloc(size);
#endif //DEBUG
}

void mnFree(void* ptr)
{
#ifdef DEBUG
    if (clearRecords)
    {
        memset(allocationRecords, 0,  MN_MAX_NUM_DEBUG_ALLOCATION_RECORDS * sizeof(mnAllocationRecord));
        clearRecords = 0;
    }
    
    mnAllocationRecord* record = NULL;
    for (int i = 0; i <  MN_MAX_NUM_DEBUG_ALLOCATION_RECORDS; i++)
    {
        if (allocationRecords[i].ptr == ptr)
        {
            record = &allocationRecords[i];
            break;
        }
    }
    
    if (!record)
    {
        assert(0 && "attempting to  MN_FREE a pointer that was not allocated using  MN_MALLOC");
        return;
    }
    
    numLiveBytes -= record->size;
    free(record->ptr);
    
    printf("freed pointer %p, live bytes %ld\n", record->ptr, numLiveBytes);
    
    memset(record, 0, sizeof(mnAllocationRecord));
    
    
#else
    free(ptr);
#endif //DEBUG
}
