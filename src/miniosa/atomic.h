#ifndef  MN_ATOMIC_H
#define  MN_ATOMIC_H

/*! \file */ 

#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */
    
    /**
     *
     */
    int mnAtomicLoad(int* value);
    
    /**
     *
     */
    void mnAtomicStore(int newValue, int* destination);
    
    /**
     *
     */
    int mnAtomicAdd(int* value, int amount);
    
#ifdef __cplusplus
} //extern "C"
#endif /* __cplusplus */

#endif // MN_ATOMIC_H
