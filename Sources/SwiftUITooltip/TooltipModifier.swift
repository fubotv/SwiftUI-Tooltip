//
//  Tooltip.swift
//
//  Created by Antoni Silvestrovic on 19/10/2020.
//  Copyright © 2020 Quassum Manus. All rights reserved.
//

import SwiftUI

struct TooltipModifier<TooltipContent: View>: ViewModifier {
    // MARK: - Uninitialised properties
    var enabled: Bool
    var config: TooltipConfig
    var content: TooltipContent


    // MARK: - Initialisers

    init(enabled: Bool, config: TooltipConfig, @ViewBuilder content: @escaping () -> TooltipContent) {
        self.enabled = enabled
        self.config = config
        self.content = content()
    }

    // MARK: - Local state

    @State private var contentWidth: CGFloat = 10
    @State private var contentHeight: CGFloat = 10

    @State var xPosition: CGFloat = 0
    @State var yPosition: CGFloat = 0

    @State var animationOffset: CGFloat = 0
    @State var animation: Optional<Animation> = nil

    // MARK: - Computed properties

    var showArrow: Bool { config.showArrow && config.side.shouldShowArrow() }
    var actualArrowHeight: CGFloat { self.showArrow ? config.arrowHeight : 0 }

    // MARK: - Helper functions

    private func arrowXPosition(_ g: GeometryProxy) -> CGFloat {
        return (contentWidth + g.size.width) / 2 - xPosition(g)
    }

    private func arrowYPosition(_ g: GeometryProxy) -> CGFloat {
        switch config.side {
        case .bottom:
            return (config.borderWidth - actualArrowHeight) / 2
        case .top:
            return contentHeight + (actualArrowHeight - config.borderWidth) / 2
        }
    }

    private func xPosition(_ g: GeometryProxy) -> CGFloat {
        let gutter: CGFloat = config.gutter
        var x: CGFloat = g.size.width / 2
        let frame = g.frame(in: .global)
        if frame.midX + contentWidth / 2 > UIScreen.main.bounds.width - gutter {
            x -= frame.midX + contentWidth / 2 - UIScreen.main.bounds.width + gutter
        } else if frame.midX - contentWidth / 2 < gutter {
            x += contentWidth / 2 - frame.midX + gutter
        }

        return x
    }

    private func yPosition(_ g: GeometryProxy) -> CGFloat {
        let offset = contentHeight / 2 + config.borderWidth + actualArrowHeight + config.margin

        if config.side == .top {
            return -offset
        } else {
            return g.size.height + offset
        }
    }
    
    // MARK: - Animation stuff
    
    private func dispatchAnimation() {
        if (config.enableAnimation) {
            DispatchQueue.main.asyncAfter(deadline: .now() + config.animationTime) {
                self.animationOffset = config.animationOffset
                self.animation = config.animation
                DispatchQueue.main.asyncAfter(deadline: .now() + config.animationTime*0.1) {
                    self.animationOffset = 0
                    
                    self.dispatchAnimation()
                }
            }
        }
    }

    // MARK: - TooltipModifier Body Properties

    private var sizeMeasurer: some View {
        GeometryReader { g in
            Text("")
                .onAppear {
                    self.contentWidth = config.width ?? g.size.width
                    self.contentHeight = config.height ?? g.size.height
                }
        }
    }

    private func arrowView(_ g: GeometryProxy) -> some View {
        guard let arrowAngle = config.side.getArrowAngleRadians() else {
            return AnyView(EmptyView())
        }
        
        return AnyView(ArrowShape()
            .rotation(Angle(radians: arrowAngle))
            .stroke(config.borderColor, lineWidth: config.borderWidth)

            .background(ArrowShape()
                .offset(x: 0, y: 1)
                .rotation(Angle(radians: arrowAngle))
                .frame(width: config.arrowWidth+2, height: config.arrowHeight+1)
                .foregroundColor(config.backgroundColor)
                
            )
                .frame(width: config.arrowWidth, height: config.arrowHeight)
                .position(x: arrowXPosition(g), y: arrowYPosition(g)))
    }

    private func arrowCutoutMask(_ g: GeometryProxy) -> some View {
        guard let arrowAngle = config.side.getArrowAngleRadians() else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            ZStack {
                Rectangle()
                    .frame(
                        width: self.contentWidth + config.borderWidth * 2,
                        height: self.contentHeight + config.borderWidth * 2)
                    .foregroundColor(.white)
                Rectangle()
                    .frame(
                        width: config.arrowWidth,
                        height: config.arrowHeight + config.borderWidth)
                    .rotationEffect(Angle(radians: arrowAngle))
                    .position(x: arrowXPosition(g) + config.borderWidth, y: arrowYPosition(g) + actualArrowHeight / 2)
                    .foregroundColor(.black)
            }
            .compositingGroup()
            .luminanceToAlpha()
        )
    }

    var tooltipBody: some View {
        GeometryReader { g in
            ZStack {
                RoundedRectangle(cornerRadius: config.borderRadius)
                    .strokeBorder(config.borderColor, lineWidth: config.borderWidth)
                    .frame(width: contentWidth, height: contentHeight)
                    .background(
                        RoundedRectangle(cornerRadius: config.borderRadius)
                            .foregroundColor(config.backgroundColor)
                    )
                    .mask(self.arrowCutoutMask(g))
                
                ZStack {
                    content
                        .padding(config.contentPaddingEdgeInsets)
                        .frame(
                            width: config.width,
                            height: config.height
                        )
                        .fixedSize(horizontal: config.width == nil, vertical: true)
                }
                .background(self.sizeMeasurer)
                .overlay(self.arrowView(g))
            }
            .position(x: xPosition, y: yPosition)
            .animation(self.animation)
            .zIndex(config.zIndex)
            .onAppear {
                self.dispatchAnimation()
                Task { @MainActor in
                    xPosition = xPosition(g)
                    yPosition = yPosition(g)
                }
            }
        }
    }

    // MARK: - ViewModifier properties

    func body(content: Content) -> some View {
        content
            .overlay(enabled ? tooltipBody.transition(config.transition) : nil)
    }
}

struct Tooltip_Previews: PreviewProvider {
    static var previews: some View {
        var config = DefaultTooltipConfig(side: .top)
        config.enableAnimation = false        
        
        return VStack {
            Text("Say...").tooltip(config: config) {
                Text("Something nice!")
            }
        }.previewDevice(.init(stringLiteral: "iPhone 12 mini"))
    }
}
