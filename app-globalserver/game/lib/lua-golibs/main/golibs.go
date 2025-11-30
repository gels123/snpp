package main

/*
#include <stdio.h>
#include <stdlib.h>
*/
import "C"
import (
	"fmt"
	"sensitivewords"
	"sync"
	"unsafe"
)

var (
	mp sync.Map
)

//export sensitiveWordNewFilter
func sensitiveWordNewFilter() uintptr {
	filter := sensitivewords.New()
	fmt.Println("sensitiveWordNewFilter filter=", filter, uintptr(unsafe.Pointer(filter)))
	ptr := uintptr(unsafe.Pointer(filter))
	mp.Store(ptr, filter)
	return ptr
}

//export sensitiveWordDelFilter
func sensitiveWordDelFilter(ptr uintptr) {
	//filter := *(*sensitivewords.Filter)(unsafe.Pointer(ptr))
	fmt.Println("sensitiveWordDelFilter ptr=", ptr)
	mp.Delete(ptr)
}

//export sensitiveWordLoadDict
func sensitiveWordLoadDict(ptr uintptr, path string) {
	//filter := *(*sensitivewords.Filter)(unsafe.Pointer(ptr))
	val, ok := mp.Load(ptr)
	if !ok {
		fmt.Println("sensitiveWordLoadDict error ptr=", ptr, " path=", path, ok)
		return
	}
	if filter, ok := val.(*sensitivewords.Filter); ok {
		fmt.Println("sensitiveWordLoadDict ptr=", ptr, " path=", path, filter)
		filter.LoadWordDict(path)
	}
}

//export sensitiveWordReplace
func sensitiveWordReplace(ptr uintptr, text string, repl rune) *C.char {
	//filter := *(*sensitivewords.Filter)(unsafe.Pointer(ptr))
	val, ok := mp.Load(ptr)
	if !ok {
		fmt.Println("sensitiveWordReplace error ptr=", ptr, ok)
		return nil
	}
	if filter, ok := val.(*sensitivewords.Filter); ok {
		//fmt.Println("sensitiveWordReplace ptr=", ptr, " text=", text, repl, filter)
		return C.CString(filter.Replace(text, repl))
	} else {
		return nil
	}
}

//export sensitiveWordValidate
func sensitiveWordValidate(ptr uintptr, text string) bool {
	//filter := *(*sensitivewords.Filter)(unsafe.Pointer(ptr))
	val, ok := mp.Load(ptr)
	if !ok {
		fmt.Println("sensitiveWordValidate error ptr=", ptr, text, ok)
		return false
	}
	if filter, ok := val.(*sensitivewords.Filter); ok {
		fmt.Println("sensitiveWordValidate ptr=", ptr, " text=", text, filter)
		isValid, _ := filter.Validate(text)
		return isValid
	} else {
		return false
	}
}

//export freeString
func freeString(p *C.char) {
	if p != nil {
		C.free(unsafe.Pointer(p))
	}
}

func main() {
	fmt.Println("==golibs main==")
	filter := sensitiveWordNewFilter()
	filter2 := *(*sensitivewords.Filter)(unsafe.Pointer(filter))
	filter2.LoadWordDict("../sensitivewords/dict.txt")
	filter2.AddWord("狗东西")
	fmt.Println(filter2.Validate("我嘞个草你妈的B"))
	fmt.Println(filter2.Validate("来来来看JJ了"))
}
