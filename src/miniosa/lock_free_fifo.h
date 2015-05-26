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
    typedef struct mnLockFreeFIFO
    {
        int capacity;
        int elementSize;
        void* elements;
        /** Only manipulated through atomic operations. Only changed by the consumer thread.*/
        int head;
        /** Only accessed through atomic operations. Only changed by the producer thread.*/
        int tail;
    } mnLockFreeFIFO;
    
    /**
     *
     */
    void mnLockFreeFIFO_init(mnLockFreeFIFO* fifo, int capacity, int elementSize);
    
    /**
     *
     */
    void mnLockFreeFIFO_deinit(mnLockFreeFIFO* fifo);
    
    /**
     *
     */
    int mnLockFreeFIFO_isEmpty(mnLockFreeFIFO* fifo);
    
    /**
     *
     */
    int mnLockFreeFIFO_isFull(mnLockFreeFIFO* fifo);
    
    /**
     *
     */
    int mnLockFreeFIFO_getNumElements(mnLockFreeFIFO* fifo);
    
    /**
     * Called from the producer thread only.
     */
    int mnLockFreeFIFO_push(mnLockFreeFIFO* fifo, const void* element);
    
    /**
     * Called from the consumer thread only.
     */
    int mnLockFreeFIFO_pop(mnLockFreeFIFO* fifo, void* element);
    
#ifdef __cplusplus
} //extern "C"
#endif /* __cplusplus */

#endif //MN_LOCK_FREE_FIFO_H
