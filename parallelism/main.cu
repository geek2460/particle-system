#include <stdio.h>
#include <iostream>

#define GLEW_STATIC
#include <GL/glew.h>
// GLFW
#include <GLFW/glfw3.h>
//CUDA
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
// Other includes
#include "Shader.h"
#include "Particle.h"
#include "Utility.h"

#define GRAVITY 2000 //some constants I need
#define DRAG 10
#define RESTITUTION_COEFFICIENT 1 // how much energy must be absorbed when bouncing off a wall
#define INITIAL_DISTANCE 0.01 // how far particles are one another initially
#define MOUSE_FORCE -20000
#define CHUNK_NB 10 // separating particles in smaller chunks to avoid having HUGE arrays (1 billion particles) : else we might face stack overflow or framerate drops. To understand the code faster, you can think that CHUNK_NB = 1
#define VERTEX_CHUNK 100000 // how much particles are in each chunk
#define PARTICLE_SIZE 10000//how much particles totally

// Function prototypes
void key_callback(GLFWwindow* window, int key, int scancode, int action, int mode);
void mouse_callback(GLFWwindow* window, double xpos, double ypos);
void mouse_button_callback(GLFWwindow* window, int button, int action, int mods);
cudaError_t addWithCuda(int *c, const int *a, const int *b, unsigned int size);

// Window dimensions
const GLuint WIDTH = 800, HEIGHT = 600;
GLfloat deltaTime = 0.0f;
GLfloat lastFrame = 0.0f;
GLfloat FPS = 0.0f;
const int particleRow = 100;
const int particleCol = PARTICLE_SIZE/ particleRow;
vec2 mousePos = vec2(0, 0);
bool LMB = false; // is left mouse button hit ?
float dt = 0.003;
using namespace std;
using namespace glm;
__global__ void addKernel(int *c, const int *a, const int *b)
{
	int i = threadIdx.x;
	c[i] = a[i] + b[i];
}

int main()
{
	////////////////////////////////////////////////
	//
	//	CUDA part
	//
	/////////////////////////////////////////////////
	const int arraySize = 5;
	const int a[arraySize] = { 1, 2, 3, 4, 5 };
	const int b[arraySize] = { 10, 20, 30, 40, 50 };
	int c[arraySize] = { 0 };

	// Add vectors in parallel.
	cudaError_t cudaStatus = addWithCuda(c, a, b, arraySize);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "addWithCuda failed!");
		return 1;
	}

	printf("{1,2,3,4,5} + {10,20,30,40,50} = {%d,%d,%d,%d,%d}\n",
		c[0], c[1], c[2], c[3], c[4]);

	// cudaDeviceReset must be called before exiting in order for profiling and
	// tracing tools such as Nsight and Visual Profiler to show complete traces.
	cudaStatus = cudaDeviceReset();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceReset failed!");
		return 1;
	}

	////////////////////////////////////////////////
	//
	//	GL part
	//
	/////////////////////////////////////////////////
	// Init GLFW
	vector<Particle> particles; // an array storing Particle instances (that we'll move)
	int particleSize = PARTICLE_SIZE; // avoid repeating particles.size() during the for loop to save some time (remember that the for loop is done 1 billion time per frame !
	for (int i(0); i < particleRow; i++) // storing Particle instances in the particles array
	{
		for (int j(0); j < particleCol; j++)
		{
			Particle particle; // see Particle.h and Particle.cpp
			particle.setPosition(vec2(j*INITIAL_DISTANCE, i*INITIAL_DISTANCE)); // we place the particles in a square shape
			particle.setMass(10);
			particles.push_back(particle);
		}
	}

	glfwInit();
	// Set all the required options for GLFW
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

	// Create a GLFWwindow object that we can use for GLFW's functions
	GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "LearnOpenGL", nullptr, nullptr);
	glfwMakeContextCurrent(window);

	// Set the required callback functions
	glfwSetKeyCallback(window, key_callback);
	glfwSetCursorPosCallback(window, mouse_callback);
	glfwSetMouseButtonCallback(window, mouse_button_callback);
	// Set this to true so GLEW knows to use a modern approach to retrieving function pointers and extensions
	glewExperimental = GL_TRUE;
	// Initialize GLEW to setup the OpenGL Function pointers
	glewInit();

	// Define the viewport dimensions
	glViewport(0, 0, WIDTH, HEIGHT);


	// Build and compile our shader program
	Shader ourShader("vs.txt", "fs.txt");


	// Set up vertex data (and buffer(s)) and attribute pointers
	GLfloat* vertices =  new GLfloat [PARTICLE_SIZE * 6];
	/*GLfloat vertices[] = {
		// Positions         // Colors
		0.5f, -0.5f, 0.0f,   1.0f, 0.0f, 0.0f,  // Bottom Right
		-0.5f, -0.5f, 0.0f,   0.0f, 1.0f, 0.0f,  // Bottom Left
		0.0f,  0.5f, 0.0f,   0.0f, 0.0f, 1.0f   // Top 
	};
	*/
	GLuint VBO, VAO;
	glGenVertexArrays(1, &VAO);
	glGenBuffers(1, &VBO);
	// Bind the Vertex Array Object first, then bind and set vertex buffer(s) and attribute pointer(s).
	glBindVertexArray(VAO);

	glBindBuffer(GL_ARRAY_BUFFER, VBO);
	glBufferData(GL_ARRAY_BUFFER, PARTICLE_SIZE * 6 * sizeof(GLfloat), vertices, GL_DYNAMIC_DRAW);
	//cout << "PARTICLE_SIZE * 6 * sizeof(float):" << PARTICLE_SIZE * 6 * sizeof(float) << endl;
	// Position attribute
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)0);
	glEnableVertexAttribArray(0);
	// Color attribute
	glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)(3 * sizeof(GLfloat)));
	glEnableVertexAttribArray(1);

	glBindVertexArray(0); // Unbind VAO

	//glEnable(GL_POINT_SMOOTH); // allow to have rounded dots
	//glEnable(GL_BLEND);
	//glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glPointSize(2);
	// Game loop
	while (!glfwWindowShouldClose(window))
	{
		// Set frame time
		GLfloat currentFrame = glfwGetTime();
		deltaTime = currentFrame - lastFrame;
		FPS = 60.0f / deltaTime;
		if (deltaTime >= 1.0)
		{
			lastFrame = currentFrame;
			cout << FPS << endl;
			cout << particles[0].getSpeed().x << ", " << particles[0].getSpeed().y << ":" << sqrt(pow(particles[0].getSpeed().x, 2) + pow(particles[0].getSpeed().y, 2)) << endl;
		}
		// Check if any events have been activiated (key pressed, mouse moved etc.) and call corresponding response functions
		glfwPollEvents();

		for (int i(0); i < particleSize; i++) // now, each frame, we want to update each particle's position according to the newton's law, color according to its speed, and maybe make it collide with walls (this for loop is executed 1 billion times each frame)
		{
			//particles[i].addForce(Vector2f(0,GRAVITY)) ; // example for adding gravity force
			particles[i].addForce((vec2(mousePos - particles[i].getPosition()) * (float)(LMB * 10000 / pow(Distance(mousePos, particles[i].getPosition())+5, 2)))); 
			// if the user clicks we add a force proportionnal to the inverse of the distance squared
			particles[i].addForce(-particles[i].getSpeed()*(float)DRAG); 
			// we add a drag force proportionnal to the speed

		    //previousPosition = particles[i].getPosition() ; // uncomment this line if you want to perform collision detection
			particles[i].updatePosition(dt); // we update the position of the particle according to the Newton's law (see Particle.h and Particle.cpp)

			particles[i].clearForce(); // we don't want forces to add over time so we clear them before adding them the next frame

									   /*for(int j(0) ; j < wallPoints.size() ; j+=2) // uncomment these lines if you want to perform collision detection
									   {
									   if(determinant(wallPoints[j+1] - wallPoints[j], wallPoints[j+1]-particles[i].getPosition())*determinant(wallPoints[j+1] - wallPoints[j], wallPoints[j+1]-previousPosition)<0) // if we crossed a wall during this frame
									   {
									   Vector2f v = wallPoints[j+1] - wallPoints[j] ; // vector directing the wall
									   Vector2f n = Vector2f(-v.y,v.x) ; // vector normal to the wall
									   n/=Norm(n) ; // we want the normal vector to be a unit vector (length = 1)
									   particles[i].setPosition(previousPosition) ; // we put the particle in its previous position (in front of the wall, since it passed it)
									   float j = -(1+RESTITUTION_COEFFICIENT)*dotProduct(particles[i].getSpeed(), n) ; // we compute the speed after bouncing off

									   particles[i].setSpeed(particles[i].getSpeed() + j*n) ; // we change the speed
									   }
									   }*/

		}
		for (int i(0); i < particleSize; i++) // we convert Vector2f positions to the OpenGL's way of storing positions : static arrays of floats
		{
			
			vertices[ i*6 ] = particles[i].getPosition().x;
			vertices[i*6 + 1] = particles[i].getPosition().y;
			vertices[i*6 + 2] = 0.0f;
			vertices[i*6 + 3] = clamp(100 * Norm(particles[i].getSpeed()), 0, 255);
			vertices[i*6 + 4] = clamp(255-100*Norm(particles[i].getSpeed()), 0, 255); // we change the particle's colors according to their speed
			vertices[i*6 + 5] = 0.0f;
			
		}
		glBindVertexArray(VAO);
		glBindBuffer(GL_ARRAY_BUFFER, VBO);
		glBufferData(GL_ARRAY_BUFFER, PARTICLE_SIZE * 6 * sizeof(GLfloat), vertices, GL_DYNAMIC_DRAW);

		// Render
		// Clear the colorbuffer
		glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);

		// Draw the triangle
		ourShader.Use();
		
		glDrawArrays(GL_POINTS, 0, particleSize);
		//glDrawArrays(GL_TRIANGLES, 0, 3);
		
		glBindVertexArray(0);

		// Swap the screen buffers
		glfwSwapBuffers(window);
	}
	// Properly de-allocate all resources once they've outlived their purpose
	delete[] vertices;
	glDeleteVertexArrays(1, &VAO);
	glDeleteBuffers(1, &VBO);
	// Terminate GLFW, clearing any resources allocated by GLFW.
	glfwTerminate();

	return 0;
}


// Helper function for using CUDA to add vectors in parallel.
cudaError_t addWithCuda(int *c, const int *a, const int *b, unsigned int size)
{
	int *dev_a = 0;
	int *dev_b = 0;
	int *dev_c = 0;
	cudaError_t cudaStatus;

	// Choose which GPU to run on, change this on a multi-GPU system.
	cudaStatus = cudaSetDevice(0);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		goto Error;
	}

	// Allocate GPU buffers for three vectors (two input, one output)    .
	cudaStatus = cudaMalloc((void**)&dev_c, size * sizeof(int));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	cudaStatus = cudaMalloc((void**)&dev_a, size * sizeof(int));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	cudaStatus = cudaMalloc((void**)&dev_b, size * sizeof(int));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	// Copy input vectors from host memory to GPU buffers.
	cudaStatus = cudaMemcpy(dev_a, a, size * sizeof(int), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

	cudaStatus = cudaMemcpy(dev_b, b, size * sizeof(int), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

	// Launch a kernel on the GPU with one thread for each element.
	addKernel << <1, size >> >(dev_c, dev_a, dev_b);

	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "addKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching addKernel!\n", cudaStatus);
		goto Error;
	}

	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(c, dev_c, size * sizeof(int), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

Error:
	cudaFree(dev_c);
	cudaFree(dev_a);
	cudaFree(dev_b);

	return cudaStatus;
}

// Is called whenever a key is pressed/released via GLFW
void key_callback(GLFWwindow* window, int key, int scancode, int action, int mode)
{
	if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS)
		glfwSetWindowShouldClose(window, GL_TRUE);
}

void mouse_callback(GLFWwindow* window, double xpos, double ypos)
{
	mousePos = vec2(2*xpos/WIDTH - 1 ,-2*ypos/HEIGHT + 1 );
}

void mouse_button_callback(GLFWwindow* window, int button, int action, int mods)
{
	if (button == GLFW_MOUSE_BUTTON_LEFT && action == GLFW_PRESS)
	{
		LMB = true;
		cout << "mousePos:" << mousePos.x << ", " << mousePos.y << endl;

	}
	else
	{
		LMB = false;
	}
}