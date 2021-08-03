"""
Slightly adapted from https://github.com/scikit-image/scikit-image/blob/v0.17.2/skimage/segmentation/random_walker_segmentation.py

Summary of changes:
 - image -> graph happens in images.py, the functions here only work on graphs
 - image.py only supports 2D images with a channel dimension (which may have length 1 of course)
 - some parameters like spacing have been removed
 - the weights returned by the functions in image.py are positive, so the calculation
   of the Laplacian has been adapted (it expected negative weights as input)
 - removed support for negative labels (for pixels that are to be ignored)


====================================================
License of the original scikit-image implementation:
====================================================

Copyright (C) 2019, the scikit-image team
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.
 3. Neither the name of skimage nor the names of its contributors may be
    used to endorse or promote products derived from this software without
    specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
"""

"""
Random walker segmentation algorithm

from *Random walks for image segmentation*, Leo Grady, IEEE Trans
Pattern Anal Mach Intell. 2006 Nov;28(11):1768-83.

Installing pyamg and using the 'cg_mg' mode of random_walker improves
significantly the performance.
"""


import numpy as np
from scipy import sparse


def warn(message):
    print(message)


# executive summary for next code block: try to import umfpack from
# scipy, but make sure not to raise a fuss if it fails since it's only
# needed to speed up a few cases.
# See discussions at:
# https://groups.google.com/d/msg/scikit-image/FrM5IGP6wh4/1hp-FtVZmfcJ
# https://stackoverflow.com/questions/13977970/ignore-exceptions-printed-to-stderr-in-del/13977992?noredirect=1#comment28386412_13977992
try:
    from scipy.sparse.linalg.dsolve import umfpack
    old_del = umfpack.UmfpackContext.__del__

    def new_del(self):
        try:
            old_del(self)
        except AttributeError:
            pass
    umfpack.UmfpackContext.__del__ = new_del
    UmfpackContext = umfpack.UmfpackContext()
except ImportError:
    UmfpackContext = None

try:
    from pyamg import ruge_stuben_solver
    amg_loaded = True
except ImportError:
    amg_loaded = False

from scipy.sparse.linalg import cg, spsolve
import scipy
import functools

cg = functools.partial(cg, atol=0)


def _build_laplacian(edges, weights):
    # Build the sparse linear system
    pixel_nb = edges.shape[1]
    i_indices = edges.ravel()
    j_indices = edges[::-1].ravel()
    data = -np.hstack((weights, weights))
    lap = sparse.coo_matrix((data, (i_indices, j_indices)),
                            shape=(pixel_nb, pixel_nb))
    lap.setdiag(-np.ravel(lap.sum(axis=0)))
    return lap.tocsr()


def _build_linear_system(edges, weights, labels, nlabels):
    """
    Build the matrix A and rhs B of the linear system to solve.
    A and B are two block of the laplacian of the image graph.
    """
    labels = labels.ravel()

    indices = np.arange(labels.size)
    seeds_mask = labels > 0
    unlabeled_indices = indices[~seeds_mask]
    seeds_indices = indices[seeds_mask]

    lap_sparse = _build_laplacian(edges, weights)

    rows = lap_sparse[unlabeled_indices, :]
    lap_sparse = rows[:, unlabeled_indices]
    B = -rows[:, seeds_indices]

    seeds = labels[seeds_mask]
    seeds_mask = sparse.csc_matrix(np.hstack(
        [np.atleast_2d(seeds == lab).T for lab in range(1, nlabels + 1)]))
    rhs = B.dot(seeds_mask)

    return lap_sparse, rhs


def _solve_linear_system(lap_sparse, B, tol, mode):

    if mode is None:
        mode = 'cg_j'

    if mode == 'cg_mg' and not amg_loaded:
        warn('"cg_mg" not available, it requires pyamg to be installed. '
             'The "cg_j" mode will be used instead.',
             stacklevel=2)
        mode = 'cg_j'

    if mode == 'bf':
        X = spsolve(lap_sparse, B.toarray()).T
    else:
        maxiter = None
        if mode == 'cg':
            if UmfpackContext is None:
                warn('"cg" mode may be slow because UMFPACK is not available. '
                     'Consider building Scipy with UMFPACK or use a '
                     'preconditioned version of CG ("cg_j" or "cg_mg" modes).',
                     stacklevel=2)
            M = None
        elif mode == 'cg_j':
            M = sparse.diags(1.0 / lap_sparse.diagonal())
        else:
            # mode == 'cg_mg'
            lap_sparse = lap_sparse.tocsr()
            ml = ruge_stuben_solver(lap_sparse)
            M = ml.aspreconditioner(cycle='V')
            maxiter = 30
        cg_out = [
            cg(lap_sparse, B[:, i].toarray(), tol=tol, M=M, maxiter=maxiter)
            for i in range(B.shape[1])]
        if np.any([info > 0 for _, info in cg_out]):
            warn("Conjugate gradient convergence to tolerance not achieved. "
                 "Consider decreasing beta to improve system conditionning.",
                 stacklevel=2)
        X = np.asarray([x for x, _ in cg_out])

    return X


def random_walker(n, edges, weights, labels, mode='cg_j', tol=1.e-3,
                  return_full_prob=True):
    """Random walker algorithm for segmentation from markers."""
    # Parse input data
    if mode not in ('cg_mg', 'cg', 'bf', 'cg_j', None):
        raise ValueError(
            "{mode} is not a valid mode. Valid modes are 'cg_mg',"
            " 'cg', 'cg_j', 'bf' and None".format(mode=mode))

    labels_dtype = labels.dtype

    label_vals = np.unique(labels)
    if not (label_vals == 0).any():
        warn("No unlabelled nodes! Unlabelled nodes should have label 0")
    nlabels = len(np.unique(labels)) - 1

    # Build the linear system (lap_sparse, B)
    lap_sparse, B = _build_linear_system(edges, weights, labels, nlabels)

    # Solve the linear system lap_sparse X = B
    # where X[i, j] is the probability that a marker of label i arrives
    # first at pixel j by anisotropic diffusion.
    X = _solve_linear_system(lap_sparse, B, tol, mode)

    if return_full_prob:
        mask = labels == 0

        out = np.zeros((nlabels, n))
        for lab, (label_prob, prob) in enumerate(zip(out, X), start=1):
            label_prob[mask] = prob
            label_prob[labels == lab] = 1
    else:
        X = np.argmax(X, axis=0) + 1
        out = labels.astype(labels_dtype)
        out[labels == 0] = X

    return out
