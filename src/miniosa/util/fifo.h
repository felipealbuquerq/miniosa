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

#ifndef MN_LOCK_FREE_FIFO_H
#define MN_LOCK_FREE_FIFO_H

/*! \file */ 

#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */
    
    /**
     * Single reader, single writer lock free FIFO.
     */
    typedef struct mnFIFO
    {
        int capacity;
        int elementSize;
        void* elements;
        /** Only manipulated through atomic operations. Only changed by the consumer thread.*/
        int head;
        /** Only accessed through atomic operations. Only changed by the producer thread.*/
        int tail;
    } mnFIFO;
    
    /**
     *
     */
    void mnFIFO_init(mnFIFO* fifo, int capacity, int elementSize);
    
    /**
     *
     */
    void mnFIFO_deinit(mnFIFO* fifo);
    
    /**
     *
     */
    int mnFIFO_isEmpty(mnFIFO* fifo);
    
    /**
     *
     */
    int mnFIFO_isFull(mnFIFO* fifo);
    
    /**
     *
     */
    int mnFIFO_getNumElements(mnFIFO* fifo);
    
    /**
     * Called from the producer thread only.
     */
    int mnFIFO_push(mnFIFO* fifo, const void* element);
    
    /**
     * Called from the consumer thread only.
     */
    int mnFIFO_pop(mnFIFO* fifo, void* element);
    
#ifdef __cplusplus
} //extern "C"
#endif /* __cplusplus */

#endif //MN_LOCK_FREE_FIFO_H
