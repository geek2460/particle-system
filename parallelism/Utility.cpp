#include "Utility.h"
float Distance(vec2 const& v1, vec2 const& v2)
{
	float distance = sqrt(pow((v2.x - v1.x), 2) + pow((v2.y - v1.y), 2));
	return distance;
}

float Norm(vec2 const& v)
{
	float result = sqrt(pow(v.x, 2) + pow(v.y, 2));
	return result;
}

float clamp(float value, float min, float max)
{
	float result;
	if (value > max)
		result = max;
	else if (value < min)
		result = min;
	else
		result = value;
	return result;
}