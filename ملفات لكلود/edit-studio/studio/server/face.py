#!/usr/bin/env python3

import json
import sys


def main():
    files = sys.argv[1:]
    try:
        import cv2
        import mediapipe as mp
        det = mp.solutions.face_detection.FaceDetection(model_selection=1, min_detection_confidence=0.5)
    except Exception as e:
        print(json.dumps({'error': 'no face tool: %s' % e}))
        return
    out = []
    for f in files:
        faces = []
        try:

            import numpy as np
            img = cv2.imdecode(np.fromfile(f, dtype=np.uint8), cv2.IMREAD_COLOR)
            res = det.process(cv2.cvtColor(img, cv2.COLOR_BGR2RGB)) if img is not None else None
            for d in (res.detections if res and res.detections else []):
                b = d.location_data.relative_bounding_box
                faces.append({'x': b.xmin, 'y': b.ymin, 'w': b.width, 'h': b.height, 'c': float(d.score[0])})
        except Exception:
            faces = []
        out.append(faces)
    print(json.dumps(out))


if __name__ == '__main__':
    main()
