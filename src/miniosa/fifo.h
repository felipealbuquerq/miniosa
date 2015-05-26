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
