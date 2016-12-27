#pragma once
#ifndef PARTICLE_H
#define PARTICLE_H
#include<glm/glm.hpp>
#include<glm/gtc/type_ptr.hpp>
#include<vector>
using namespace glm;
using namespace std;
class Particle
{
public:
	Particle();
	Particle(float mass, vec2 position, vec2 speed);

	vector<vec2> getForce() const;
	vec2 getTotalForce() const;
	void addForce(vec2 const& force);
	void clearForce();

	float getMass() const;
	void setMass(float const& mass);
	vec2 getPosition() const;
	void setPosition(vec2 const& position);
	vec2 getSpeed() const;
	void setSpeed(vec2 const& speed);
	vec2 getAcceleration() const;
	void setAcceleration(vec2 const& acceleration);
	void setStatic();
	void setMovable();
	bool isMovable() const;
	void updatePosition(float const& dt); // the only important method in this class !
private:
	float m_mass;

	vector<vec2> m_force; // forces applied to this particle
	vec2 m_position; // position of the particle
	vec2 m_speed; // speed of the particle : speed v= ( x(t+dt) - x(t) ) / dt is the finite manner to say v=dx/dt
	vec2 m_acceleration; // acceleration of the particle : acceleration a= ( v(t+dt) - v(t) ) / dt is the finite manner to say a=dv/dt

	bool m_movable;

};
#endif