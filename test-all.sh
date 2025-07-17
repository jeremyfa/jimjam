#!/bin/bash

haxe build-php.hxml && php bin/php/index.php && haxe build-cpp.hxml && bin/cpp/Test && haxe build-cppia.hxml && haxelib run hxcpp bin/test.cppia
