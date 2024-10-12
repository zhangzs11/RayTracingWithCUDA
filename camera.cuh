#ifndef CAMERAH
#define CAMERAH

#include <curand_kernel.h>

#include "ray.cuh"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

__device__ vec3 random_in_unit_disk(curandState* local_rand_state) {
    vec3 p;
    do {
        p = 2.0f * vec3(curand_uniform(local_rand_state), curand_uniform(local_rand_state), 0) - vec3(1, 1, 0);
    } while (dot(p, p) >= 1.0f);
    return p;
}

class camera {
public:
    __device__ camera(vec3 lookfrom, vec3 lookat, vec3 vup, float vfov, float aspect, float aperture, float focus_dist) {
        // vfov is top to bottom in degrees
        lens_radius = aperture / 2.0f; // 影响blur的程度
        float theta = vfov * ((float)M_PI) / 180.0f;
        float half_height = tan(theta / 2.0f);
        float half_width = aspect * half_height;
        origin = lookfrom;
        w = unit_vector(lookfrom - lookat);
        u = unit_vector(cross(vup, w));
        v = cross(w, u);
        lower_left_corner = origin - half_width * focus_dist * u - half_height * focus_dist * v - w * focus_dist;
        horizontal = 2 * half_width * focus_dist * u;
        vertical = 2 * half_height * focus_dist * v;
       
    }
    __device__ ray get_ray(float s, float t, curandState* local_rand_state) {
        vec3 rd = lens_radius * random_in_unit_disk(local_rand_state);
        vec3 offset = u * rd.x() + v * rd.y();
        return ray(origin + offset, lower_left_corner + s * horizontal + t * vertical - origin - offset);
        // 当s, t确定时,lower_left_corner + s * horizontal + t * vertical也是确定的，就是距离摄像头负方向focus_dist的那个焦点平面的点，
        // 因为w方向就lower_left_corner这里修改了- w * focus_dist，所以是摄像头负方向focus_dist的那个焦点平面的点
        // 所以不管offset怎么偏移，这个ray起码都是瞄准焦点平面的焦点的
        // 但是瞄准到同一个点，如果正好射到该点，也就是距离恰好是focus_dist,那就正好汇集，如果近了或远了，那不同的光线就不汇集同一个点，算出的结果也不同，就模糊了
        // 
        // 当fov和aspect确定了之后,相当于ray的方向是固定的了，就是通过fov和aspect确定所有像素的ray的方向，
        // 如果修改focus_dist，相当于，修改焦点的w深度，此时因为方向确定了，为了ray指向这个焦点，焦点的坐标我们也要重新计算，具体就是u和v和w一起等比例调整，因为ray的方向没变
        // 所谓的horizontal和vertical，并不是影响相机视角，仅仅是作为ray在不同像素移动的步长，比如每移动一个像素，ray的方向如何移动，由于我们的方向是由原点和焦点做差获得
        // 所以就算u和v移动的步长增加或减少，但是焦点的w也就是focus_dist也是等比例移动，所以方向的改变还是一样的角度
        // 就好像如果焦点近的话，每一个像素的ray同样角度的改变，落实在焦点的uv的移动就很小，如果焦点很远的话，同样角度的变化，落实到焦点uv的移动就很大
        // u,v范围(也是步长，因为st是从0到1固定范围)随着focus_dist，也就是焦点的w等比例缩放，恰恰是为了让焦点，这个用于计算ray方向的点，不会随着他w的取值的变化影响视角fov，从而等比例缩放uv
        // 至于为什么非用这个w可变化的焦点作为计算ray的第二个点，而不用一个固定w的点，这样u,v的移动也就固定了，是因为用焦点作为计算ray的方向的点，即使origin的点有一定范围随机的偏移，依然在焦点是汇聚清晰的
        // 仅仅是为了这个，除此之外，焦点就是个普通的用于计算ray方向的点，话说回来fov和aspect确定后，方向就确定了
        // 另外这个焦点，对于每一个像素都有一个各自的焦点目标，他们只有w也就是focus_dist一样，u和v方向也随着像素的移动而移动
        // 
        // 总而言之：u 和 v 随着 focus_dist 等比例缩放，其目的是确保焦点平面的物理尺寸随着 focus_dist 的变化而调整。这样可以保证当 focus_dist 改变时，视角（FOV）不发生变化
    }

    vec3 origin;
    vec3 lower_left_corner;
    vec3 horizontal;
    vec3 vertical;

    vec3 u, v, w;
    float lens_radius;
};

#endif // CAMERAH