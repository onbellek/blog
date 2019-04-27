---
layout: post
permalink: /latex/
latex: true
author: baskin
---

# Latex Ipsum Dolor Sit Amet
$$
\begin{align*}
   \text{minimize } & \int_{0}^{T_i}\left\|f_i(t)-o_i(t)\right\|^2 dt\\
   \text{subject to }& \\
   &f_i(t) \text{ is}\text{ continuous up to degree $c$},\\
   &\frac{d^jf_i}{dt^j}(0) = \frac{d^jp_i}{dt^j}(0)\text{ for } j\in\{0,1,...,c\}\\
   &f_i(t)\text{ is collision-free, and}\\ 
   &\left\|\frac{d^k f_i(t)}{dt^k}\right\| \leq \gamma_k\text{ for all desired $k$},\\
   \text{where } & t\in [0,T_i].
\end{align*}
$$