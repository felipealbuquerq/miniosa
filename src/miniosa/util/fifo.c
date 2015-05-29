/*
 The MIT License (MIT)
 
 Copyright (c) 2015 Per Gantelius
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

#include <stdlib.h>
#include <string.h>
#include "fifo.h"
#include "atomic.h"

/*Based on http://www.codeproject.com/Articles/43510/Lock-Free-Single-Producer-Single-Consumer-Circular*/

void mnFIFO_init(mnFIFO* fifo, int capacity, int elementSize)
{
    memset(fifo, 0, sizeof(mnFIFO));
    fifo->capacity = capacity + 1;
    fifo->elementSize = elementSize;
    fifo->elements =  malloc(fifo->capacity * elementSize);
}

void mnFIFO_deinit(mnFIFO* fifo)
{
    if (fifo->elements)
    {
         free(fifo->elements);
    }
    
    memset(fifo, 0, sizeof(mnFIFO));   
}

static int increment(int idx, int capacity)
{
    return (idx + 1) % capacity;
}

int mnFIFO_isEmpty(mnFIFO* fifo)
{
    return mnAtomicLoad(&fifo->head) == mnAtomicLoad(&fifo->tail);
}

int mnFIFO_isFull(mnFIFO* fifo)
{
    const int nextTail = increment(mnAtomicLoad(&fifo->tail), fifo->capacity);
    return nextTail == mnAtomicLoad(&fifo->head);
}

int mnFIFO_getNumElements(mnFIFO* fifo)
{
    const int currentTail = mnAtomicLoad(&fifo->tail);
    const int currentHead = mnAtomicLoad(&fifo->head);
    
    const int d = currentTail - currentHead;
    return d < 0 ? d + fifo->capacity : d;
}

int mnFIFO_push(mnFIFO* fifo, const void* element)
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

int mnFIFO_pop(mnFIFO* fifo, void* element)
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