using System;
using System.Text;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

public class DataBuffer<T> :IDisposable where T :struct
{
    public ComputeBuffer computeBuffer;
    public DataBuffer(int size,T initialValue):this(size)
    {
        T[] array = new T[size];
        for(int i = 0;i<size;i++)
            array[i] = initialValue;
        computeBuffer.SetData(array);    
    }

    public DataBuffer(int size)
    {
        // ComputeBufferType.Structured:结构化数组，每个元素是 T 结构体
        computeBuffer = new ComputeBuffer(size,Marshal.SizeOf(typeof(T)), ComputeBufferType.Structured);
    }

    public void SetData(T[] array)
    {
        computeBuffer.SetData(array);
    }

    public void GetData(out T[] array)
    {
        array = new T[computeBuffer.count];
        computeBuffer.GetData(array);
    }
    public void Dispose()
    {
        computeBuffer?.Release();
    }
}
