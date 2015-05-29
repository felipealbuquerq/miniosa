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

#include <libkern/OSAtomic.h>

#include "atomic.h"


int mnAtomicLoad(int* value)
{
    return OSAtomicAdd32Barrier(0, value);
}

void mnAtomicStore(int newValue, int* destination)
{
    while (true)
    {
        int oldValue = *destination;
        if (OSAtomicCompareAndSwap32Barrier(oldValue, newValue, destination))
        {
            return;
        }
    }
}

int mnAtomicAdd(int* value, int amount)
{
    return OSAtomicAdd32Barrier(amount, value);
}
