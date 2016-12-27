#pragma once
#ifndef UTILITY_H
#define UTILITY_H
#include <math.h>
#include <cmath>
#include <iostream>
#include<glm/glm.hpp>
#include<glm/gtc/type_ptr.hpp>

#define PI 3.14159265359

using namespace std;
using namespace glm;

float Distance(vec2 const& v1, vec2 const& v2);
float Norm(vec2 const& v);
float clamp(float value, float min, float max);

#endif