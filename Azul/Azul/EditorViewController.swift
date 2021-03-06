//
//  EditorViewController.swift
//  Azul
//
//  Created by German Villacorta on 1/21/20.
//  Copyright © 2020 Azul. All rights reserved.
//
//  Vista mostrada después de tomar una fotografía.
//  Maneja el recorte manual de la imagen, el cambio de contraste
//  y el almacenamiento de la imagen.

import UIKit
import Photos

extension CGSize {
    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }
}

class EditorViewController: UIViewController {
    
//   Cropp
    var maskImage: UIImage! = nil
    var imageData: Data?
    var lastPoint = CGPoint.zero
    var startPoint = CGPoint.zero
    var color = UIColor.yellow
    var brushWidth: CGFloat = 5.0
    var opacity: CGFloat = 0.5
    
//    Contorno
    var colorShape = UIColor.red
    var brushWidthShape : CGFloat = 5.0
    var opacityShape : CGFloat = 0.9
    var swiped = false
    
    var minX: CGFloat = CGFloat.greatestFiniteMagnitude
    var maxX: CGFloat = CGFloat.leastNormalMagnitude
    var minY: CGFloat = CGFloat.greatestFiniteMagnitude
    var maxY: CGFloat = CGFloat.leastNormalMagnitude
    
    var cropRectangle: CGRect?
    var isCropping = false
    var isShapping = false
    
    var merged = false
        
    @IBOutlet weak var currentImage: UIImageView!
    
    @IBOutlet weak var canvas: UIImageView!
    @IBOutlet weak var cropButton: UIButton!
    @IBOutlet weak var doneCroppingButton: UIButton!
    @IBOutlet weak var shapeButton: UIButton!
    @IBOutlet weak var shapeButtonOff: UIButton!
    
    private var previewImage: UIImage! = nil;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        currentImage.image = UIImage(data: self.imageData!)
        if maskImage != nil {
            let mask = CALayer()
            mask.contents = maskImage.cgImage
            mask.contentsGravity = .resizeAspect
            mask.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
            mask.anchorPoint = CGPoint(x:0.5, y:0.5)
            currentImage.layer.mask = mask
            currentImage.clipsToBounds = true
            
            UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, self.view.isOpaque, 0.0)
            defer { UIGraphicsEndImageContext() }
            if let context = UIGraphicsGetCurrentContext() {
                currentImage.layer.render(in: context)
                let image = UIGraphicsGetImageFromCurrentImageContext()
                currentImage.layer.mask = nil
                currentImage.image = image
                currentImage.contentMode = .scaleAspectFill
            }
        }
        previewImage = currentImage.image
        
        canvas.backgroundColor = UIColor.clear
        
        doneCroppingButton.isEnabled = false
        doneCroppingButton.isHidden = true
    }
    

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        guard let touch = touches.first else {
          return
        }
        
        if (isCropping == false && isShapping == false) {
            return
        } else if(isShapping == true){
            swiped = false
            resetCanvas()
            resetCropRectangle()
            lastPoint = touch.location(in: canvas)
            startPoint = lastPoint
        } else if isCropping == true {
            resetCanvas()
            resetCropRectangle()
            
            

            lastPoint = touch.location(in: canvas)
            startPoint = lastPoint
        }

        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
           
        guard let touch = touches.first else {
            return
        }
        
        if (isCropping == false && isShapping == false) {
            return
        } else if (isCropping){
            let currentPoint = touch.location(in: view)
            drawLine(from: lastPoint, to: currentPoint)
            
            //Update mins & maxs para hacer el rectangulo.
            minX = min(minX, currentPoint.x)
            minY = min(minY, currentPoint.y)
            
            maxX = max(maxX, currentPoint.x)
            maxY = max(maxY, currentPoint.y)
            
            lastPoint = currentPoint
        } else if(isShapping){
            swiped = true
            
            let currentPoint = touch.location(in: view)
            drawLine(from: lastPoint, to: currentPoint)
            
            //Update mins & maxs para hacer el rectangulo.
            minX = min(minX, currentPoint.x)
            minY = min(minY, currentPoint.y)
            
            maxX = max(maxX, currentPoint.x)
            maxY = max(maxY, currentPoint.y)
              
            lastPoint = currentPoint
        }
        
        

        
       }
       
    //Cada que el usuario deje de oprimir la pantalla. Touch == tocar. Ended == terminar. Pollito == Chicken.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        guard let touch = touches.first else {
            return
        }
        
        if(isShapping){
            if !swiped {
                // draw a single point
                let currentPoint = touch.location(in: view)
                drawLine(from: currentPoint, to: startPoint)
                drawRect()
                print("!Swiped")
            }
            
            let currentPoint = touch.location(in: view)
            drawLine(from: currentPoint, to: startPoint)
            drawRect()
            
            // Merge canvas into currentImage
            UIGraphicsBeginImageContext(currentImage.frame.size)
            currentImage.image?.draw(in: view.bounds, blendMode: .normal, alpha: 1.0)
            canvas?.image?.draw(in: view.bounds, blendMode: .normal, alpha: opacity)
            if !merged{
            currentImage.image = UIGraphicsGetImageFromCurrentImageContext()
                merged = true
            }
            
            UIGraphicsEndImageContext()
              
            canvas.image = nil
        }
           
        if (isCropping == false) {
            return
        }
        
        

        let currentPoint = touch.location(in: view)
        drawLine(from: currentPoint, to: startPoint)
        drawRect()
       }
    
    // Crop Button - Empieza a trazar lineas.
    @IBAction func beginCropping(_ sender: Any) {
        isCropping = true
        isShapping = false
        shapeButtonOff.isHidden = true
        shapeButtonOff.isEnabled = false
        shapeButton.isHidden = true
        shapeButton.isEnabled = false
        
        cropButton.isHighlighted = true
        
        doneCroppingButton.isEnabled = true
        doneCroppingButton.isHidden = false
        doneCroppingButton.tintColor = cropButton.tintColor
    }
    
    // Done Cropping Button - Cuando el usuario este de acuerdo con el rectangulo para recortar. La imagen se actualiza.
    @IBAction func doneCropping(_ sender: Any) {
        guard let rect = cropRectangle as CGRect? else {
            return
        }
        // Si existia un rectangulo se desactiva la opcion de dibujar el recuadro
        // y el boton para terminar de recortar desaparece.
        isCropping = false

        doneCroppingButton.isEnabled = false
        doneCroppingButton.isHidden = true
        
        currentImage.image = snapshot(in: currentImage, rect: rect)
        
        shapeButton.isHidden = false
        shapeButton.isEnabled = true
    }
    
    // Crea alerta si la imagen se guardo exitosamente.
    func successfullySavedPhoto() {
        let alert = UIAlertController(title: "Finalizado", message: "La imagen se ha guardado exitosamente", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler:nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    // Funcion que guarda la imagen en la libreria del dispositivo.
    @IBAction func saveImageToCameraRoll(_ sender: Any) {
         let alerta = UIAlertController(title: "¿Deseas guardar esta foto?", message: "Asegurate de que el defecto se vea claramente y que lo hayas marcado", preferredStyle: .alert)
               
               let guardarFoto = UIAlertAction(title: "Guardar", style: .default, handler: { (action) -> Void in
                   print("Guardar button tapped")
                   
                   let data = self.currentImage.image?.pngData()!
                   
                   PHPhotoLibrary.requestAuthorization { status in
                       if status == .authorized {
                           PHPhotoLibrary.shared().performChanges({
                               let options = PHAssetResourceCreationOptions()
                               let creationRequest = PHAssetCreationRequest.forAsset()
                               creationRequest.addResource(with: .photo, data: data!, options: options)
                               
                               // No se puede llamar nuevos ViewController desde otra thread que
                               // no sea main. Por eso esta cosa.
                               DispatchQueue.main.async {
                                   self.successfullySavedPhoto()
                               }
                           })
                       }
                   }
                   
               })
               
               let cancelar = UIAlertAction(title: "Cancelar y Tomar foto nuevamente", style: .cancel, handler: { (action) -> Void in
                   print("Cancel button tapped")
                   self.cancel((Any).self)
               })
               
               alerta.addAction(cancelar)
               alerta.addAction(guardarFoto)
               
               self.present(alerta, animated: true, completion: nil)
    }
    // Restart Button - Regresa la imagen a su estado natural.
    @IBAction func restoreImage(_ sender: Any) {
        currentImage.image = previewImage;
        merged = false
        isCropping = false
        isShapping = false
        shapeButton.isHidden = false
        shapeButton.isEnabled = true
        shapeButtonOff.isHidden = true
        shapeButtonOff.isEnabled = false
        doneCroppingButton.isHidden = true
        doneCroppingButton.isEnabled = false
    }
    
    // Cancel Button - Regresa a la camara.
    @IBAction func cancel(_ sender: Any) {
        self.dismiss(animated: false, completion: nil)
        merged = false
    }
    
    // Funcion para dibujar linea. Draw line == dibujar linea en ingles. Mundo de ingles de Disney.
    func drawLine(from fromPoint: CGPoint, to toPoint: CGPoint) {

        UIGraphicsBeginImageContext(view.frame.size)
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        canvas.image?.draw(in: view.bounds)
        
        context.setLineCap(.square)
        context.setBlendMode(.normal)
        context.setLineWidth(brushWidth)
        context.setStrokeColor(color.cgColor)
        
        if(isShapping){
            context.setLineWidth(brushWidthShape)
            context.setStrokeColor(colorShape.cgColor)
        }
        
        context.move(to: fromPoint)
        context.addLine(to: toPoint)
      
        context.strokePath()
      
        canvas.image = UIGraphicsGetImageFromCurrentImageContext()
        canvas.alpha = opacity
        UIGraphicsEndImageContext()
    }
    
    // Dibuja un rectangulo con base en el trazo que hizo el usuario.
    func drawRect() {
        
        resetCanvas()
        
        UIGraphicsBeginImageContext(view.frame.size)
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        canvas.image?.draw(in: view.bounds)
                  
        context.setLineCap(.square)
        context.setLineDash(phase: 3.0, lengths: [10, 10])
        context.setLineWidth(brushWidth)
        context.setStrokeColor(color.cgColor)
        
        if(isShapping){
            context.setLineWidth(brushWidthShape)
            context.setStrokeColor(colorShape.cgColor)
        }
          
        // El rectangulo se crea con base en los puntos minimos y maximos de X e Y.
        let rectangle = CGRect(x: minX - 10, y: minY - 10, width: maxX - minX + 25, height: maxY - minY + 25)
        
        self.cropRectangle = rectangle
        
        context.addRect(rectangle)
        context.strokePath()
        
        canvas.image = UIGraphicsGetImageFromCurrentImageContext()
        canvas.alpha = opacity
          UIGraphicsEndImageContext()
        
    }

    // Quita la linea que tiene.
    func resetCanvas() {
        canvas.image = nil
    }
    
    // Resetea los puntos para el rectangulo.
    func resetCropRectangle() {
        cropRectangle = nil
        
        minX = CGFloat.greatestFiniteMagnitude
        maxX = CGFloat.leastNormalMagnitude
        minY = CGFloat.greatestFiniteMagnitude
        maxY = CGFloat.leastNormalMagnitude
    }
    
    // Esta funcion hace el recorte de la imagen con el rectangulo seleccionado.
    func snapshot(in imageView: UIImageView, rect: CGRect) -> UIImage {

        let image = imageView.image!

        let imageRatio = imageView.bounds.width / imageView.bounds.height
        let imageViewRatio = image.size.width / image.size.height

        let scale: CGFloat
        if imageRatio > imageViewRatio {
            scale = image.size.height / imageView.bounds.height
        } else {
            scale = image.size.width / imageView.bounds.width
        }

        let size = rect.size * scale
        let origin = CGPoint(x: image.size.width  / 2 - (imageView.bounds.midX - rect.minX) * scale,
                             y: image.size.height / 2 - (imageView.bounds.midY - rect.minY) * scale)
        let scaledRect = CGRect(origin: origin, size: size)

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        resetCanvas()
        resetCropRectangle()
        
        return UIGraphicsImageRenderer(bounds: scaledRect, format: format).image { _ in
            image.draw(at: .zero)
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    //Aumenta el contraste modificando el inputContrast y aplicando el filtro
    @IBAction func contrastUp(_ sender: Any) {
        let inputImage = CIImage(image: self.currentImage.image!)!
        /*Por cada presión se aumenta el contraste un valor de .1, el máximo siendo 2 */
        let parameters = [
            "inputContrast": NSNumber(value: 1.1)
        ]
        let outputImage = inputImage.applyingFilter("CIColorControls", parameters: parameters)

        let context = CIContext(options: nil)
        let img = context.createCGImage(outputImage, from: outputImage.extent)!
        
        self.currentImage.image = UIImage(cgImage: img)
    }
    
    //Reduce el contraste modificando el inputContrast y aplicando el filtro
    @IBAction func contrastDown(_ sender: Any) {
        
        let inputImage = CIImage(image: self.currentImage.image!)!
        
        /*Por cada presión se aumenta el contraste un valor de -.1, el mínimo siendo 0 */
        let parameters = [
            "inputContrast": NSNumber(value: 0.9)
        ]
        let outputImage = inputImage.applyingFilter("CIColorControls", parameters: parameters)

        let context = CIContext(options: nil)
        let img = context.createCGImage(outputImage, from: outputImage.extent)!
        
        self.currentImage.image = UIImage(cgImage: img)
    }
    
    //    Boton que activa la funcionalidad de que el usuario pueda marcar el contorno del defecto
    @IBAction func marcarContorno(_ sender: Any) {
        shapeButton.isHidden = true
        shapeButton.isEnabled = false
        
        shapeButtonOff.isHidden = false
        shapeButtonOff.isEnabled = true
        
        isShapping = true
        isCropping = false
        print("activa")
    }
    
    
    @IBAction func desactivaContorno(_ sender: Any) {
        shapeButton.isHidden = false
        shapeButton.isEnabled = true
        
        shapeButtonOff.isHidden = true
        shapeButtonOff.isEnabled = false
        
        isShapping = false
        print("desactiva")
    }
    
    
    
}
