#include <GL/glut.h>
#include <math.h>

float angle = 0;

void rotate(float *x, float *y, float phi)
{
    float x0 = *x;
    float y0 = *y;
    *x = x0 * cosf(phi) - y0 * sinf(phi);
    *y = x0 * sinf(phi) + y0 * cosf(phi);
}

void display()
{
    glClear(GL_COLOR_BUFFER_BIT);

    float x = 0.6;
    float y = 0.75;

    rotate(&x, &y, angle);
        
    glBegin(GL_TRIANGLES);
        glColor3f(1, 0, 0);
        glVertex2f(x, y);
        glColor3f(0, 1, 0);
        rotate(&x, &y, 2 * 3.141592654f / 3);
        glVertex2f(x, y);
        glColor3f(0, 0, 1);
        rotate(&x, &y, 2 * 3.141592654f / 3);
        glVertex2f(x, y);
        
    glEnd();

    glutSwapBuffers();
}

void idle()
{
    angle += 0.01;
    glutPostRedisplay();
}

int main(int argc, char **argv)
{
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGB);

    glutInitWindowPosition(20, 60);
    glutInitWindowSize(384, 384);
    glutCreateWindow("Hello, OpenGL");

    glutDisplayFunc(display);
    glutIdleFunc(idle);

    glutMainLoop();
}