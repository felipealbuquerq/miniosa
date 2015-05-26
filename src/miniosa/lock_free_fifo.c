#include <stdlib.h>
#include <string.h>
#include "lock_free_fifo.h"
#include "atomic.h"
#include "mem.h"

/*Based on http://www.codeproject.com/Articles/43510/Lock-Free-Single-Producer-Single-Consumer-Circular*/

void mnLockFreeFIFO_init(mnLockFreeFIFO* fifo, int capacity, int elementSize)
{
    memset(fifo, 0, sizeof(mnLockFreeFIFO));
    fifo->capacity = capacity + 1;
    fifo->elementSize = elementSize;
    fifo->elements =  MN_MALLOC(fifo->capacity * elementSize, "FIFO elements");
}

void mnLockFreeFIFO_deinit(mnLockFreeFIFO* fifo)
{
    if (fifo->elements)
    {
         MN_FREE(fifo->elements);
    }
    
    memset(fifo, 0, sizeof(mnLockFreeFIFO));   
}

static int increment(int idx, int capacity)
{
    return (idx + 1) % capacity;
}

int mnLockFreeFIFO_isEmpty(mnLockFreeFIFO* fifo)
{
    return mnAtomicLoad(&fifo->head) == mnAtomicLoad(&fifo->tail);
}

int mnLockFreeFIFO_isFull(mnLockFreeFIFO* fifo)
{
    const int nextTail = increment(mnAtomicLoad(&fifo->tail), fifo->capacity);
    return nextTail == mnAtomicLoad(&fifo->head);
}

int mnLockFreeFIFO_getNumElements(mnLockFreeFIFO* fifo)
{
    const int currentTail = mnAtomicLoad(&fifo->tail);
    const int currentHead = mnAtomicLoad(&fifo->head);
    
    const int d = currentTail - currentHead;
    return d < 0 ? d + fifo->capacity : d;
}

int mnLockFreeFIFO_push(mnLockFreeFIFO* fifo, const void* element)
{    
    int currentTail = mnAtomicLoad(&fifo->tail);
    const int nextTail = increment(currentTail, fifo->capacity);
    if(nextTail != mnAtomicLoad(&fifo->head))
    {
        memcpy(&(((unsigned char*)fifo->elements)[currentTail * fifo->elementSize]), element, fifo->elementSize);
        mnAtomicStore(nextTail, &fifo->tail);
        return 1;
    }
    return 0;
}

int mnLockFreeFIFO_pop(mnLockFreeFIFO* fifo, void* element)
{
    const int currentHead = mnAtomicLoad(&fifo->head);
    if(currentHead == mnAtomicLoad(&fifo->tail))
    {
        return 0; // empty queue
    }
    
    memcpy(element, &fifo->elements[currentHead * fifo->elementSize], fifo->elementSize);
    mnAtomicStore(increment(currentHead, fifo->capacity), &fifo->head);
    return 1;
}